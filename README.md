# untrusted-agent

An AI agent that cannot leak its own API key, because it has never seen it.

The agent box holds zero secrets. It talks to OpenRouter through a Cloud Run
function that holds role-based access to Secret Manager and stamps the real
key onto requests in flight. The box's only credential is its ambient GCP
identity, which is useless anywhere except the proxy's IAM policy.

```
pi (on VM) ── dummy key ──> sidecar (127.0.0.1:8787)
                              │  swaps in a Google-signed ID token
                              │  from the metadata server
                              v
                            openrouter-proxy (Cloud Run function)
                              │  IAM: only the VM's service account may invoke
                              │  swaps in the real key from Secret Manager
                              v
                            openrouter.ai
```

Trust boundaries:

* The VM's service account has `run.invoker` on the proxy, log/metric writer,
  and nothing else. No Secret Manager access anywhere in its reach.
* The proxy's service account is the only principal with `secretAccessor` on
  the OpenRouter key secret.
* The VM has no external IP (egress via Cloud NAT) and accepts SSH only from
  IAP's tunnel range.
* The real key never enters tofu state: the secret version is created
  write-only with a placeholder, and the live value is added out of band.

## Layout

* `tofu/` — the whole stack (project, secret, proxy function, VM). State on
  R2 via the `cloudflare` AWS profile, `unstable` workspace.
* `proxy/` — Node 24 source for the Cloud Run function; zipped and deployed
  by tofu.

## Deploying

The project itself is created out of band, once:

```sh
gcloud projects create untrusted-agent
gcloud billing projects link untrusted-agent \
  --billing-account $(gcloud billing accounts list --format 'value(name)')
```

Then:

```sh
cd tofu
tofu init
tofu workspace new unstable   # first time only
tofu apply
```

Notes for the first apply:

* Requires `gcloud auth application-default login` credentials.
* API enablement is eventually consistent, so if the first apply fails on a
  freshly enabled API, just apply again.

Then give the proxy the real key (never via tofu):

```sh
echo -n "sk-or-..." | gcloud secrets versions add \
  untrusted_agent-unstable-openrouter_api_key \
  --project untrusted-agent --data-file=-
```

The function reads version `latest`, so rotation is the same command again.

## Using the agent

```sh
gcloud compute ssh untrusted-agent-unstable --project untrusted-agent \
  --zone us-central1-a --tunnel-through-iap
pi --model openrouter/anthropic/claude-sonnet-4.5
```

`~/.pi/agent/models.json` (seeded from `/etc/skel` by the startup script)
points pi's OpenRouter provider at the sidecar with the literal api key
`not_the_key`. Add models there as needed; the proxy passes any OpenRouter
model through.

## Future direction

SSH-in-and-run-pi is the MVP. The same pattern — an IAM-gated Cloud Run
function holding the credential, an ambient-identity sidecar on the box —
extends to messaging apps and any other integration the agent should use but
never hold keys for.
