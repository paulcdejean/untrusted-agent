// Cloud Run function fronting OpenRouter. Cloud Run IAM verifies the caller's
// Google-signed ID token before this code runs; this function then swaps that
// identity for the real OpenRouter key, which only its own service account can
// read from Secret Manager. Callers never see the key.
const functions = require('@google-cloud/functions-framework');
const { Readable } = require('node:stream');

const UPSTREAM = 'https://openrouter.ai';

functions.http('proxy', async (req, res) => {
  const url = new URL(req.originalUrl, UPSTREAM);

  const headers = {
    authorization: 'Bearer ' + process.env.OPENROUTER_API_KEY,
  };
  for (const name of ['content-type', 'accept', 'x-title', 'http-referer']) {
    const value = req.get(name);
    if (value) headers[name] = value;
  }

  const init = { method: req.method, headers, redirect: 'manual' };
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    init.body = req.rawBody ?? '';
  }

  let upstream;
  try {
    upstream = await fetch(url, init);
  } catch (err) {
    res.status(502).json({ error: 'proxy: upstream request failed: ' + err.message });
    return;
  }

  res.status(upstream.status);
  for (const name of ['content-type', 'cache-control', 'x-request-id']) {
    const value = upstream.headers.get(name);
    if (value) res.set(name, value);
  }
  if (upstream.body) {
    Readable.fromWeb(upstream.body).pipe(res);
  } else {
    res.end();
  }
});
