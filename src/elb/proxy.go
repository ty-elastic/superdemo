package main

import (
	"context"
	"io"
	"net"
	"net/http"
	"net/http/httputil"
	"time"
)

// proxyCtxKey is the context key for per-request proxy metadata.
type proxyCtxKey struct{}

// proxyCtxVal carries per-request state shared between the handler, Director,
// ModifyResponse, and ErrorHandler hooks.
type proxyCtxVal struct {
	backend    *Backend         // selected backend; nil if 503 short-circuit
	traceID    string           // TID_<32hex>
	startTime  time.Time        // when the request entered the handler
	reqReader  *countingReader  // nil for bodyless requests (GET/HEAD)
	clientAddr string
	clientPort int
	urlFull    string
	method     string
	proto      string // e.g. "1.1"
}

func setProxyCtx(ctx context.Context, v *proxyCtxVal) context.Context {
	return context.WithValue(ctx, proxyCtxKey{}, v)
}

func getProxyCtx(ctx context.Context) *proxyCtxVal {
	v, _ := ctx.Value(proxyCtxKey{}).(*proxyCtxVal)
	return v
}

// countingReader wraps an io.ReadCloser and counts bytes read.
// Used to track the request body size forwarded to backends.
type countingReader struct {
	io.ReadCloser
	count int64
}

func (r *countingReader) Read(p []byte) (int, error) {
	n, err := r.ReadCloser.Read(p)
	r.count += int64(n)
	return n, err
}

// buildReverseProxy creates an httputil.ReverseProxy wired to the given pool,
// metric aggregator, access-log buffer, and config.
func buildReverseProxy(
	pool *BackendPool,
	agg *lbAgg,
	logBuf *accessLogBuffer,
	cfg *Config,
	lbCfg LBConfig,
) *httputil.ReverseProxy {

	transport := &http.Transport{
		DialContext: (&net.Dialer{
			Timeout:   10 * time.Second,
			KeepAlive: 30 * time.Second,
		}).DialContext,
		ResponseHeaderTimeout: 30 * time.Second,
		IdleConnTimeout:       90 * time.Second,
		MaxIdleConnsPerHost:   100,
		TLSHandshakeTimeout:   10 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
	}

	rp := &httputil.ReverseProxy{
		Transport: transport,

		// Director rewrites the outgoing request to point at the selected backend.
		Director: func(req *http.Request) {
			pv := getProxyCtx(req.Context())
			if pv == nil || pv.backend == nil {
				return
			}
			b := pv.backend
			req.URL.Scheme = b.URL.Scheme
			req.URL.Host = b.URL.Host
			// Prepend the backend's path prefix if set (e.g. "/api").
			if b.URL.Path != "" && b.URL.Path != "/" {
				req.URL.Path = b.URL.Path + req.URL.Path
			}
			req.Host = b.URL.Host

			// Propagate client IP.
			if prior, ok := req.Header["X-Forwarded-For"]; ok {
				req.Header["X-Forwarded-For"] = append(prior, pv.clientAddr)
			} else {
				req.Header.Set("X-Forwarded-For", pv.clientAddr)
			}
			req.Header.Set("X-Forwarded-Host", req.Host)
			req.Header.Set("X-Forwarded-Proto", "http")
		},

		// ModifyResponse is called after the backend responds successfully.
		// Records metrics and appends an access-log doc.
		ModifyResponse: func(resp *http.Response) error {
			pv := getProxyCtx(resp.Request.Context())
			if pv == nil {
				return nil
			}

			elapsed := time.Since(pv.startTime)
			targetSec := elapsed.Seconds()

			var reqSize int64
			if pv.reqReader != nil {
				reqSize = pv.reqReader.count
			}

			var respSize int64
			if resp.ContentLength >= 0 {
				respSize = resp.ContentLength
			}

			backendURL := ""
			if pv.backend != nil {
				backendURL = pv.backend.URL.String()
			}

			agg.RecordRequest(backendURL, resp.StatusCode, reqSize, respSize, targetSec, false)

			now := time.Now()
			doc, err := BuildAccessLogDoc(AccessLogInfo{
				Timestamp:              now,
				ObservedTimestamp:      now,
				ConnectionTraceID:      pv.traceID,
				ClientAddress:          pv.clientAddr,
				ClientPort:             pv.clientPort,
				Method:                 pv.method,
				URLFull:                pv.urlFull,
				StatusCode:             resp.StatusCode,
				RequestSize:            reqSize,
				ResponseSize:           respSize,
				ProtoVersion:           pv.proto,
				RequestProcessingTime:  0.0,
				TargetProcessingTime:   targetSec,
				ResponseProcessingTime: 0.0,
				LBName:                 lbCfg.Name,
				CloudRegion:            cfg.Resource.CloudRegion,
				CloudAccountID:         cfg.Resource.CloudAccountID,
				S3BucketName:           cfg.Resource.S3BucketName,
				S3BucketARN:            cfg.Resource.S3BucketARN,
				S3KeyPrefix:            cfg.Resource.S3KeyPrefix,
			})
			if err == nil {
				logBuf.Append(doc)
			}

			// insert log record here

			return nil
		},

		// ErrorHandler is called when the backend connection fails or times out.
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, proxyErr error) {
			pv := getProxyCtx(r.Context())

			statusCode := http.StatusBadGateway
			backendURL := ""
			if pv != nil && pv.backend != nil {
				backendURL = pv.backend.URL.String()
			}

			var reqSize int64
			if pv != nil && pv.reqReader != nil {
				reqSize = pv.reqReader.count
			}

			agg.RecordRequest(backendURL, statusCode, reqSize, 0, -1, true)

			now := time.Now()
			if pv != nil {
				doc, err := BuildAccessLogDoc(AccessLogInfo{
					Timestamp:              now,
					ObservedTimestamp:      now,
					ConnectionTraceID:      pv.traceID,
					ClientAddress:          pv.clientAddr,
					ClientPort:             pv.clientPort,
					Method:                 pv.method,
					URLFull:                pv.urlFull,
					StatusCode:             statusCode,
					RequestSize:            reqSize,
					ResponseSize:           0,
					ProtoVersion:           pv.proto,
					RequestProcessingTime:  -1,
					TargetProcessingTime:   -1,
					ResponseProcessingTime: -1,
					LBName:                 lbCfg.Name,
					CloudRegion:            cfg.Resource.CloudRegion,
					CloudAccountID:         cfg.Resource.CloudAccountID,
					S3BucketName:           cfg.Resource.S3BucketName,
					S3BucketARN:            cfg.Resource.S3BucketARN,
					S3KeyPrefix:            cfg.Resource.S3KeyPrefix,
				})
				if err == nil {
					logBuf.Append(doc)
				}
			}

			http.Error(w, http.StatusText(statusCode), statusCode)
		},
	}

	return rp
}
