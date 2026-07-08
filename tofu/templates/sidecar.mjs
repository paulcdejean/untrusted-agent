// Localhost sidecar: pi speaks the OpenAI protocol to 127.0.0.1:8787 with a
// dummy key; this process swaps the Authorization header for a Google-signed
// ID token minted by the metadata server, then forwards to the Cloud Run
// proxy. No secret ever exists on this box — the token only proves "I am the
// agent VM's service account" and is useless to anyone outside the proxy's
// IAM policy.
import http from 'node:http';
import https from 'node:https';

const proxyUrl = new URL(process.env.PROXY_URL);
const port = Number(process.env.PORT || 8787);
const audience = proxyUrl.origin;

let cache = { token: null, expiresMs: 0 };

function mintIdToken() {
  return new Promise(function (resolve, reject) {
    const request = http.get({
      host: 'metadata.google.internal',
      path: '/computeMetadata/v1/instance/service-accounts/default/identity?audience=' +
        encodeURIComponent(audience),
      headers: { 'Metadata-Flavor': 'Google' },
    }, function (response) {
      let body = '';
      response.on('data', function (chunk) { body += chunk; });
      response.on('end', function () {
        if (response.statusCode === 200) resolve(body.trim());
        else reject(new Error('metadata server returned ' + response.statusCode + ': ' + body));
      });
    });
    request.on('error', reject);
  });
}

async function idToken() {
  // Tokens live an hour; refresh five minutes early.
  if (cache.token && Date.now() < cache.expiresMs - 5 * 60 * 1000) return cache.token;
  const token = await mintIdToken();
  const claims = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString());
  cache = { token: token, expiresMs: claims.exp * 1000 };
  return token;
}

const HOP_HEADERS = [
  'connection', 'keep-alive', 'proxy-authorization', 'te', 'trailer',
  'transfer-encoding', 'upgrade', 'host',
];

http.createServer(async function (req, res) {
  let token;
  try {
    token = await idToken();
  } catch (err) {
    res.writeHead(502, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ error: 'sidecar: could not mint identity token: ' + err.message }));
    return;
  }

  const headers = {};
  for (const [name, value] of Object.entries(req.headers)) {
    if (!HOP_HEADERS.includes(name)) headers[name] = value;
  }
  headers.host = proxyUrl.host;
  headers.authorization = 'Bearer ' + token;

  // Join PROXY_URL's own path (if any) with the incoming path, so both
  // origin-style run.app URLs and path-style cloudfunctions.net URLs work.
  const basePath = proxyUrl.pathname.replace(/\/$/, '');
  const upstream = https.request(new URL(basePath + req.url, proxyUrl.origin), {
    method: req.method,
    headers: headers,
  }, function (response) {
    res.writeHead(response.statusCode, response.headers);
    response.pipe(res);
  });
  upstream.on('error', function (err) {
    if (!res.headersSent) {
      res.writeHead(502, { 'content-type': 'application/json' });
    }
    res.end(JSON.stringify({ error: 'sidecar: proxy request failed: ' + err.message }));
  });
  req.pipe(upstream);
}).listen(port, '127.0.0.1', function () {
  console.log('sidecar listening on 127.0.0.1:' + port + ' -> ' + proxyUrl.origin);
});
