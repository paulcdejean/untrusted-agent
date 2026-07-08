// Package proxy fronts OpenRouter. Cloud Run IAM verifies the caller's
// Google-signed ID token before this code runs; the proxy then swaps that
// identity for the real OpenRouter key, which only its own service account
// can read from Secret Manager. Callers never see the key.
package proxy

import (
	"net/http/httputil"
	"net/url"
	"os"

	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
)

func init() {
	target, err := url.Parse("https://openrouter.ai")
	if err != nil {
		panic(err)
	}
	proxy := &httputil.ReverseProxy{
		// Flush streamed tokens to the client as they arrive instead of
		// buffering the response.
		FlushInterval: -1,
		Rewrite: func(r *httputil.ProxyRequest) {
			r.SetURL(target)
			r.Out.Host = target.Host
			r.Out.Header.Set("Authorization", "Bearer "+os.Getenv("OPENROUTER_API_KEY"))
		},
	}
	functions.HTTP("proxy", proxy.ServeHTTP)
}
