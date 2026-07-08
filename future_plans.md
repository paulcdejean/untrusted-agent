# Future plans, in priority order

## Document the setup process

Setting up the auth for the r2 remote state for example, isn't intuitive.

## Move the proxy to a Cloudflare Worker

Replace the Cloud Run function with a Cloudflare Worker holding the
OpenRouter key in Workers Secrets. The agent VM stays on GCE and changes
almost nothing: the sidecar keeps minting ID tokens from the metadata
server, and the Worker verifies them itself instead of Cloud Run IAM doing
it:

1. Fetch Google's public JWKS from
   `https://www.googleapis.com/oauth2/v3/certs` (free, unauthenticated,
   cacheable for hours).
2. Verify the JWT signature with WebCrypto.
3. Check `iss` (accounts.google.com), `aud` (the proxy's URL), expiry, and
   that `email` equals the agent's service-account email — that last check
   replaces the `roles/run.invoker` binding.

Why: a Worker isolate idles at ~3MB and rides the free tier, versus a
container baseline on Cloud Run. The whole cross-cloud trust
chain costs $0 on both sides — no AWS-Roles-Anywhere-style private CA,
because cloud workloads already have free, auto-rotating OIDC identities
that anyone can verify with public keys.

Same pattern extends to future integrations (messaging apps etc.): each is
an IAM-verified credential-holder the box can call but never read.
