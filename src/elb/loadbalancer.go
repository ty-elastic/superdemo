package main

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"time"

	log "github.com/sirupsen/logrus"
)

// LoadBalancer is an HTTP server that round-robins requests across a backend pool
// and instruments each request with access-log docs and metric counters.
type LoadBalancer struct {
	cfg    LBConfig
	appCfg *Config
	pool   *BackendPool
	agg    *lbAgg
	logBuf *accessLogBuffer
	rp     *httputil.ReverseProxy
	server *http.Server
}

// NewLoadBalancer constructs a LoadBalancer from the given per-LB and global config.
func NewLoadBalancer(lbCfg LBConfig, appCfg *Config) (*LoadBalancer, error) {
	pool, err := newBackendPool(lbCfg.Backends)
	if err != nil {
		return nil, fmt.Errorf("backend pool: %w", err)
	}

	agg := newLBAgg()
	logBuf := newAccessLogBuffer()
	rp := buildReverseProxy(pool, agg, logBuf, appCfg, lbCfg)

	lb := &LoadBalancer{
		cfg:    lbCfg,
		appCfg: appCfg,
		pool:   pool,
		agg:    agg,
		logBuf: logBuf,
		rp:     rp,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", lb.handle)
	lb.server = &http.Server{
		Addr:         fmt.Sprintf(":%d", lbCfg.Port),
		Handler:      mux,
		ReadTimeout:  60 * time.Second,
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  120 * time.Second,
		// Track client connections for NewConnectionCount / ActiveConnectionCount.
		ConnState: func(_ net.Conn, state http.ConnState) {
			switch state {
			case http.StateNew:
				agg.ConnOpened()
			case http.StateClosed, http.StateHijacked:
				agg.ConnClosed()
			}
		},
	}
	return lb, nil
}

// handle is the HTTP handler for every inbound request. It:
//  1. Selects a healthy backend via round-robin.
//  2. Short-circuits with 503 if no backend is available.
//  3. Delegates to the reverse proxy for normal proxying.
func (lb *LoadBalancer) handle(w http.ResponseWriter, r *http.Request) {
	clientAddr, clientPort := ParseClientAddr(r.RemoteAddr)
	traceID := GenerateTraceID()
	proto := ParseProtoVersion(r.Proto)
	method := ExtractMethod(r)

	// Reconstruct the full URL as seen by the load balancer.
	fullURL := (&url.URL{
		Scheme:   "http",
		Host:     r.Host,
		Path:     r.URL.Path,
		RawQuery: r.URL.RawQuery,
	}).String()

	// Wrap body in a counting reader to track request byte size.
	var cr *countingReader
	if r.Body != nil && r.Body != http.NoBody {
		cr = &countingReader{ReadCloser: r.Body}
		r.Body = cr
	}

	backend := lb.pool.Next()

	pv := &proxyCtxVal{
		backend:    backend,
		traceID:    traceID,
		startTime:  time.Now(),
		reqReader:  cr,
		clientAddr: clientAddr,
		clientPort: clientPort,
		urlFull:    fullURL,
		method:     method,
		proto:      proto,
	}

	if backend == nil {
		// No healthy backend — return 503.
		lb.agg.RecordRequest("", http.StatusServiceUnavailable, 0, 0, -1, true)

		now := time.Now()
		doc, err := BuildAccessLogDoc(AccessLogInfo{
			Timestamp:              now,
			ObservedTimestamp:      now,
			ConnectionTraceID:      traceID,
			ClientAddress:          clientAddr,
			ClientPort:             clientPort,
			Method:                 method,
			URLFull:                fullURL,
			StatusCode:             http.StatusServiceUnavailable,
			RequestSize:            0,
			ResponseSize:           0,
			ProtoVersion:           proto,
			RequestProcessingTime:  -1,
			TargetProcessingTime:   -1,
			ResponseProcessingTime: -1,
			LBName:                 lb.cfg.Name,
			CloudRegion:            lb.appCfg.Resource.CloudRegion,
			CloudAccountID:         lb.appCfg.Resource.CloudAccountID,
			S3BucketName:           lb.appCfg.Resource.S3BucketName,
			S3BucketARN:            lb.appCfg.Resource.S3BucketARN,
			S3KeyPrefix:            lb.appCfg.Resource.S3KeyPrefix,
		})
		if err == nil {
			lb.logBuf.Append(doc)
		}
		http.Error(w, "Service Unavailable", http.StatusServiceUnavailable)
		return
	}

	ctx := setProxyCtx(r.Context(), pv)
	lb.rp.ServeHTTP(w, r.WithContext(ctx))
}

// Start begins listening. It blocks until the server is closed (via Shutdown).
func (lb *LoadBalancer) Start() {
	log.WithFields(log.Fields{
		"addr": lb.server.Addr,
		"lb":   lb.cfg.Name,
	}).Info("load balancer listening")

	if err := lb.server.ListenAndServe(); err != http.ErrServerClosed {
		log.WithField("lb", lb.cfg.Name).WithError(err).Error("load balancer error")
	}
}

// Shutdown gracefully drains in-flight requests within the given context deadline.
func (lb *LoadBalancer) Shutdown(ctx context.Context) error {
	return lb.server.Shutdown(ctx)
}
