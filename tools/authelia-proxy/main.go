// Package main implements a simple reverse proxy for Authelia
// that appends the "groups" scope if missing, to ensure group claims
// are included in the requests to upstream Authelia (relevant for OpenCloud).
package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"time"
)

const (
	DefaultServerGracefulShutdownTimeout = 10 * time.Second
	DefaultReadHeaderTimeout             = 10 * time.Second
)

func main() {
	if err := run(); err != nil {
		panic(err)
	}
}

func run() error {
	upstreamAddr := os.Getenv("PROXY_UPSTREAM_SERVER_ADDRESS")
	if upstreamAddr == "" {
		return errors.New("PROXY_UPSTREAM_SERVER_ADDRESS environment variable is required")
	}

	listenAddr := os.Getenv("PROXY_LISTEN_ADDRESS")
	if listenAddr == "" {
		return errors.New("PROXY_LISTEN_ADDRESS environment variable is required")
	}

	upstream, err := url.Parse(upstreamAddr)
	if err != nil {
		return fmt.Errorf("failed to parse upstream address: %w", err)
	}

	proxy := httputil.NewSingleHostReverseProxy(upstream)
	proxy.Director = appendGroupsOIDCScopeIfMissing(proxy.Director)

	//nolint:exhaustruct // Using default values for other fields.
	server := &http.Server{
		Addr:              listenAddr,
		Handler:           proxy,
		ReadHeaderTimeout: DefaultReadHeaderTimeout,
	}

	log.Printf("starting proxy server on '%s', forwarding to '%s'\n", listenAddr, upstreamAddr)

	go func() {
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Printf("proxy server exited with an error: %v\n", err)
		}

		log.Println("proxy server has been stopped")
	}()

	done := make(chan os.Signal, 1)
	defer close(done)

	signal.Notify(done, os.Interrupt)

	sig := <-done

	log.Printf("received signal '%s', shutting down proxy server\n", sig.String())

	ctx, cancel := context.WithTimeout(context.Background(), DefaultServerGracefulShutdownTimeout)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		return fmt.Errorf("failed to shutdown proxy server: %w", err)
	}

	log.Printf("proxy server shut down gracefully\n")

	return nil
}

func appendGroupsOIDCScopeIfMissing(original func(*http.Request)) func(*http.Request) {
	return func(req *http.Request) {
		original(req)

		log.Printf("processing request '%s %s%s' from '%s'", req.Method, req.URL.String(), req.Pattern, req.RemoteAddr)

		switch req.Method {
		case http.MethodGet:
			appendGroupsToQueryParams(req)
		case http.MethodPost:
			appendGroupsToFormBody(req)
		}
	}
}

func appendGroupsToQueryParams(req *http.Request) {
	values := req.URL.Query()

	log.Printf("received url query values: %v", values.Encode())

	if scope := values.Get("scope"); scope != "" {
		if !strings.Contains(scope, "groups") {
			values.Set("scope", scope+" groups")
			log.Printf("added 'groups' to scope in query: %s", values.Get("scope"))
		}
	}

	req.URL.RawQuery = values.Encode()
}

func appendGroupsToFormBody(req *http.Request) {
	contentType := req.Header.Get("Content-Type")
	if !strings.HasPrefix(contentType, "application/x-www-form-urlencoded") {
		return
	}

	if req.Body == nil {
		return
	}

	bodyBytes, err := io.ReadAll(req.Body)
	if err != nil {
		log.Printf("failed to read request body: %v", err)
		return
	}
	req.Body.Close()

	log.Printf("received form body: %s", string(bodyBytes))

	values, err := url.ParseQuery(string(bodyBytes))
	if err != nil {
		log.Printf("failed to parse form values: %v", err)
		req.Body = io.NopCloser(bytes.NewReader(bodyBytes))
		req.ContentLength = int64(len(bodyBytes))
		return
	}

	if scope := values.Get("scope"); scope != "" {
		if !strings.Contains(scope, "groups") {
			values.Set("scope", scope+" groups")
			log.Printf("added 'groups' to scope in body: %s", values.Get("scope"))
		}
	}

	newBody := values.Encode()
	req.Body = io.NopCloser(strings.NewReader(newBody))
	req.ContentLength = int64(len(newBody))
}
