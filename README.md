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
* The VM has no external IPv4; egress rides a free external IPv6 in a custom
  VPC with no ingress rules (the GCP analog of an AWS egress-only internet
  gateway), and SSH is accepted only from IAP's tunnel range.
* Two OpenRouter keys with different blast radii: the *provisioning* key
  exists only in the shell running tofu (`OPENROUTER_API_KEY` env var, never
  in state). The *runtime* key is minted by tofu through the management API,
  is disposable (rotation is one `-replace` away), and reaches Secret Manager
  via a write-only argument — though its value does live in the (private R2)
  state, since the provider has no ephemeral resource.

## Layout

* `tofu/` — the whole stack (project, secret, proxy function, VM). State on
  R2 via the `cloudflare` AWS profile, `unstable` workspace.
* `proxy/` — Go source for the Cloud Run function; zipped and deployed by
  tofu.

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
export OPENROUTER_API_KEY=sk-or-...   # a *provisioning* key, from openrouter.ai/settings/keys
tofu init
tofu workspace new unstable   # first time only
tofu apply
```

Tofu mints a dedicated runtime key through the OpenRouter management API and
plants it in Secret Manager itself — there is no manual key step.

Notes for the first apply:

* Requires `gcloud auth application-default login` credentials.
* API enablement is eventually consistent, so if the first apply fails on a
  freshly enabled API, just apply again.

To rotate the runtime key:

```sh
tofu apply -replace=openrouter_api_key.agent
```

which cascades new key → new secret version → new function revision (the
function pins the exact version because instances only resolve secret env
vars at startup — `latest` would go stale in warm instances).

## Using the agent

```sh
gcloud compute ssh untrusted-agent-unstable --project untrusted-agent \
  --zone us-central1-a --tunnel-through-iap
pi --model openrouter/deepseek/deepseek-v4-flash
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
