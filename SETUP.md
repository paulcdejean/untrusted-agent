# Required accounts

There's three required accounts for this. Each requires putting in a credit card.

* Cloudflare
* Google Cloud
* Openrouter

### Cloudflare, state backend

* Login to cloudflare
* Make sure R2 is enabled, your account will need to have a credit card in it to do this
* Create a bucket named "tofu"
* Go back to the R2 homepage, in the bottom right where it says "Account Details" click `{} Manage` next to API Tokens
* Create an account API token with "admin read write" permissions and a TTL of "forever
* Copy the "Access Key ID" and "Secret Access Key" the "token value" can be ignored
* Also copy your account ID, it's in your url as the first thing after dash.cloudflare.com
* Add the following code to your ~/.aws/config file, filling in `Account Id`, `Access Key ID` and `Secret Access Key` as appropriate:

```
[profile cloudflare]
aws_access_key_id=<Access Key ID>
aws_secret_access_key=<Secret Access Key>
services = cloudflare

[services cloudflare]
s3 =
  endpoint_url = https://<Account Id>.r2.cloudflarestorage.com
```

* Make sure this is copied exactly, with that exact whitespace

### Google cloud, hyperscaler

* Make sure `gcloud-cli` is installed. In homebrew this is via `brew install --cask gcloud-cli`
* Login via `gcloud auth application-default login` this will require a web flow
* Create a new project with the project name of `untrusted-agent` this can be done via the web or cli
* Associate that project with an active billing account, this can be done via the web or cli

### Openrouter, AI provider

* Login to openrouter
* If you haven't funded it, I recommend funding it with $10 to unlock increased free model usage
* Go to preferences -> management keys and create a new management key
* You'll need to put it into your environment variables under `OPENROUTER_API_KEY` on macs this is via adding it to `~/.zshrc`

# FAQ

Q: Why three seperate things? Google cloud can fufil all of these roles.
A: It's really my personal preference. Specifically though I like how R2 bucket names are not globally unique.

Q: How much money does this cost?
A: It depends on runtime and usage. I would say google cloud costs are unlikely to exceed $15 a month. Openrouter depends completely on usage, but if you fund it with $10 it won't cost more than $10. Cloudflare is throughly in the free tier.

Q: That's too expensive can this be done more cheaply with digital ocean or similar?
A: I don't think that's a good idea. Google cloud's auth story is very strong, which is the whole point of this exercise. Trying to use digital ocean would be penny wise and pound foolish.
