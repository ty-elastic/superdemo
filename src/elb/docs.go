package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/cespare/xxhash/v2"
)

// GetHostName returns the system hostname, falling back to "unknown" on error.
func GetHostName() string {
	h, err := os.Hostname()
	if err != nil {
		return "unknown"
	}
	return h
}

// GenerateTraceID returns a TID_<32hex> connection trace ID matching the reference format.
func GenerateTraceID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return "TID_" + hex.EncodeToString(b)
}

// ParseClientAddr splits an HTTP RemoteAddr "host:port" into components.
func ParseClientAddr(remoteAddr string) (string, int) {
	host, portStr, err := net.SplitHostPort(remoteAddr)
	if err != nil {
		return remoteAddr, 0
	}
	port, _ := strconv.Atoi(portStr)
	return host, port
}

// ParseProtoVersion extracts the version string from r.Proto (e.g. "HTTP/1.1" → "1.1").
func ParseProtoVersion(proto string) string {
	if v := strings.TrimPrefix(proto, "HTTP/"); v != proto {
		return v
	}
	return "-"
}

// ExtractMethod returns the HTTP method or "-" for empty/unparsed requests.
func ExtractMethod(r *http.Request) string {
	if r.Method == "" {
		return "-"
	}
	return r.Method
}

// buildS3Key returns a synthetic S3 key matching the reference log path convention:
//
//	<prefix>/<accountID>/elasticloadbalancing/<region>/<YYYY>/<MM>/<DD>/<lbShort>_<date>T<time>Z_synthetic.log.gz
func buildS3Key(prefix, accountID, region, lbName string, t time.Time) string {
	lbShort := strings.NewReplacer("/", ".").Replace(lbName)
	if prefix == "" {
		prefix = "AWSLogs"
	}
	return fmt.Sprintf(
		"%s/%s/elasticloadbalancing/%s/%04d/%02d/%02d/%s_%04d%02d%02dT%02d%02dZ_synthetic.log.gz",
		prefix, accountID, region,
		t.Year(), int(t.Month()), t.Day(),
		lbShort,
		t.Year(), int(t.Month()), t.Day(), t.Hour(), t.Minute(),
	)
}

// formatTS formats a time as RFC3339 millisecond UTC as used in the reference docs.
func formatTS(t time.Time) string {
	return t.UTC().Format("2006-01-02T15:04:05.000Z")
}

// AccessLogInfo carries all per-request data needed to build an access-log document.
type AccessLogInfo struct {
	Timestamp              time.Time
	ObservedTimestamp      time.Time
	ConnectionTraceID      string
	ClientAddress          string
	ClientPort             int
	Method                 string
	URLFull                string
	StatusCode             int
	RequestSize            int64
	ResponseSize           int64
	ProtoVersion           string
	RequestProcessingTime  float64 // seconds; -1 if N/A
	TargetProcessingTime   float64 // seconds; -1 if N/A
	ResponseProcessingTime float64 // seconds; -1 if N/A

	// Resource fields (from config)
	LBName         string
	CloudRegion    string
	CloudAccountID string
	S3BucketName   string
	S3BucketARN    string
	S3KeyPrefix    string
}

// BuildAccessLogDoc marshals an access-log document shaped after the reference
// src/elb/reference/logs/aws/elb/elbaccess.json.
func BuildAccessLogDoc(info AccessLogInfo) ([]byte, error) {
	s3BucketARN := info.S3BucketARN
	if s3BucketARN == "" && info.S3BucketName != "" {
		s3BucketARN = "arn:aws:s3:::" + info.S3BucketName
	}
	s3Key := buildS3Key(info.S3KeyPrefix, info.CloudAccountID, info.CloudRegion, info.LBName, info.Timestamp)

	doc := map[string]interface{}{
		"@timestamp": formatTS(info.Timestamp),
		"attributes": map[string]interface{}{
			"aws.elb.connection_trace_id":      info.ConnectionTraceID,
			"aws.elb.request_processing_time":  info.RequestProcessingTime,
			"aws.elb.response_processing_time": info.ResponseProcessingTime,
			"aws.elb.status.code":              info.StatusCode,
			"aws.elb.target_processing_time":   info.TargetProcessingTime,
			"client.address":                   info.ClientAddress,
			"client.port":                      info.ClientPort,
			"http.request.method":              info.Method,
			"http.request.size":                info.RequestSize,
			"http.response.size":               info.ResponseSize,
			"network.protocol.name":            "http",
			"network.protocol.version":         info.ProtoVersion,
			"url.full":                         info.URLFull,
		},
		"data_stream": map[string]string{
			"dataset":   "aws.elbaccess.otel",
			"namespace": "default",
			"type":      "logs",
		},
		"observed_timestamp": formatTS(info.ObservedTimestamp),
		"resource": map[string]interface{}{
			"attributes": map[string]interface{}{
				"aws.s3.bucket.arn":  s3BucketARN,
				"aws.s3.bucket.name": info.S3BucketName,
				"aws.s3.key":         s3Key,
				"cloud.provider":     "aws",
				"cloud.region":       info.CloudRegion,
				"cloud.resource_id":  info.LBName,
			},
		},
		"scope": map[string]interface{}{
			"attributes": map[string]string{
				"encoding.format": "aws.elbaccess",
			},
			"name": "github.com/open-telemetry/opentelemetry-collector-contrib/extension/encoding/awslogsencodingextension",
		},
	}
	return json.Marshal(doc)
}

// MetricDocParams carries the data needed to build one metric document.
type MetricDocParams struct {
	Now            time.Time
	WindowDuration time.Duration
	Def            metricDef
	Dims           DimSet    // the specific dimension combination for this doc
	LoadBalancer   string
	TargetGroup    string
	AZ             string
	CloudAccountID string
	CloudRegion    string
	HostName       string
	MetricValue    interface{} // int64 or float64
}

// BuildMetricDoc marshals a metric document shaped after the reference
// src/elb/reference/metrics/aws/elb/*.json and returns a BulkDoc whose
// DynamicTemplates maps the metric field to the appropriate OTel type.
func BuildMetricDoc(p MetricDocParams) (BulkDoc, error) {
	startTS := p.Now.Add(-p.WindowDuration)
	metricKey := "amazonaws.com/AWS/ApplicationELB/" + p.Def.Name

	hasher := xxhash.New()
	_, _ = hasher.WriteString(metricKey)

	attrs := map[string]interface{}{
		"MetricName": p.Def.Name,
		"Namespace":  "AWS/ApplicationELB",
		"stat":       p.Def.Stat,
	}
	if p.Dims.HasLB && p.LoadBalancer != "" {
		attrs["LoadBalancer"] = p.LoadBalancer
	}
	if p.Dims.HasAZ && p.AZ != "" {
		attrs["AvailabilityZone"] = p.AZ
	}
	if p.Dims.HasTG && p.TargetGroup != "" {
		attrs["TargetGroup"] = p.TargetGroup
	}

	doc := map[string]interface{}{
		"@timestamp":         formatTS(p.Now),
		"_metric_names_hash": strconv.FormatUint(hasher.Sum64(), 16),
		"attributes":         attrs,
		"data_stream": map[string]string{
			"dataset":   "aws.elb.otel",
			"namespace": "default",
			"type":      "metrics",
		},
		"metrics": map[string]interface{}{
			metricKey: p.MetricValue,
		},
		"resource": map[string]interface{}{
			"attributes": map[string]interface{}{
				"cloud.account.id": p.CloudAccountID,
				"cloud.provider":   "aws",
				"cloud.region":     p.CloudRegion,
				"host.name":        p.HostName,
				"os.type":          "linux",
			},
			"schema_url": "https://opentelemetry.io/schemas/1.40.0",
		},
		"scope": map[string]string{
			"name": "github.com/open-telemetry/opentelemetry-collector-contrib/receiver/awscloudwatchreceiver",
		},
		"start_timestamp": formatTS(startTS),
	}
	body, err := json.Marshal(doc)
	if err != nil {
		return BulkDoc{}, err
	}
	return BulkDoc{
		Body:             body,
		DynamicTemplates: map[string]string{"metrics." + metricKey: p.Def.OTelType},
	}, nil
}
