package main

// sourceKind describes how a metric value is derived from a WindowSnapshot.
type sourceKind int

const (
	srcRequestCount          sourceKind = iota // total request count
	srcRequestCountPerTarget                   // target requests / healthy targets
	srcTgt2XX                                  // HTTP 2xx from backends
	srcTgt3XX                                  // HTTP 3xx from backends
	srcTgt4XX                                  // HTTP 4xx from backends
	srcTgt5XX                                  // HTTP 5xx from backends
	srcELB3XX                                  // ELB-generated 3xx
	srcELB4XX                                  // ELB-generated 4xx
	srcELB5XX                                  // ELB-generated 5xx (includes 503)
	srcELB503                                  // ELB 503 (no healthy backend)
	srcTargetResponseTimeAvg                   // mean backend response time (float64, seconds)
	srcTargetResponseTimeMax                   // max backend response time (float64, seconds)
	srcProcessedBytes                          // total bytes in + out
	srcActiveConnectionCount                   // open client connections (gauge)
	srcNewConnectionCount                      // client connections opened during the window
	srcHealthyHostCount                        // healthy backend count
	srcUnHealthyHostCount                      // unhealthy backend count
	srcHealthyStateDNS                         // 1 if any healthy backend, else 0
	srcHealthyStateRouting                     // 1 if any healthy backend, else 0
	srcUnhealthyStateDNS                       // 1 if any unhealthy backend, else 0
	srcUnhealthyStateRouting                   // 1 if any unhealthy backend, else 0
	srcConstZero                               // always 0 (not measurable by a simple proxy)
	srcConstOne                                // always 1 (PeakLCUs placeholder)
)

// DimSet describes one CloudWatch dimension combination for a metric series.
type DimSet struct {
	HasLB bool // include LoadBalancer dimension
	HasAZ bool // include AvailabilityZone dimension (fans out per configured AZ)
	HasTG bool // include TargetGroup dimension
}

// Reusable dimension set combinations matching the AWS ApplicationELB docs.
var (
	dimLB     = DimSet{HasLB: true}
	dimLBAZ   = DimSet{HasLB: true, HasAZ: true}
	dimLBTG   = DimSet{HasLB: true, HasTG: true}
	dimLBAZTG = DimSet{HasLB: true, HasAZ: true, HasTG: true}
	dimTG     = DimSet{HasTG: true}
	dimTGAZ   = DimSet{HasAZ: true, HasTG: true}
)

// metricDef describes one AWS ApplicationELB CloudWatch metric series.
// A metric that is queried with several statistics (e.g. Average and Maximum)
// has one metricDef per statistic; "stat" is a document dimension, so these
// land in distinct time series.
type metricDef struct {
	Name     string     // CloudWatch metric name
	Stat     string     // "Sum" | "Average" | "Maximum" | "Minimum"
	DimSets  []DimSet   // dimension combinations to emit; AZ-bearing sets fan out per configured AZ
	Source   sourceKind // how the value is derived
	OTelType string     // Elasticsearch OTel dynamic template name (e.g. "gauge_long", "gauge_double")
}

// metricDefs enumerates all AWS ApplicationELB metrics we emit.
//
// The set is driven by the Elastic aws_elb_metrics_otel dashboards
// ([AWS ELB OTel] Metrics and [AWS OTel] ALB Load Balancer Detail), which read
// LB-level series via `TargetGroup IS NULL AND AvailabilityZone IS NULL`. Every
// metric those dashboards use is therefore emitted with the {LoadBalancer}
// dimension set, in addition to the AWS-documented dimension sets.
var metricDefs = []metricDef{
	// --- Connections ---------------------------------------------------------
	{Name: "ActiveConnectionCount", Stat: "Sum", DimSets: []DimSet{dimLB, dimLBAZ}, Source: srcActiveConnectionCount, OTelType: "gauge_long"},
	{Name: "ActiveConnectionCount", Stat: "Average", DimSets: []DimSet{dimLB, dimLBAZ}, Source: srcActiveConnectionCount, OTelType: "gauge_long"},
	{Name: "NewConnectionCount", Stat: "Sum", DimSets: []DimSet{dimLB, dimLBAZ}, Source: srcNewConnectionCount, OTelType: "gauge_long"},
	// This proxy has no connection limit, so it never rejects connections.
	{Name: "RejectedConnectionCount", Stat: "Sum", DimSets: []DimSet{dimLB, dimLBAZ}, Source: srcConstZero, OTelType: "gauge_long"},

	// --- Requests / bytes ----------------------------------------------------
	{Name: "RequestCount", Stat: "Sum", DimSets: []DimSet{dimLB, dimLBAZ, dimLBTG, dimLBAZTG}, Source: srcRequestCount, OTelType: "gauge_long"},
	{Name: "RequestCountPerTarget", Stat: "Sum", DimSets: []DimSet{dimTG, dimTGAZ, dimLBTG, dimLBAZTG}, Source: srcRequestCountPerTarget, OTelType: "gauge_long"},
	{Name: "ProcessedBytes", Stat: "Sum", DimSets: []DimSet{dimLB, dimLBAZ}, Source: srcProcessedBytes, OTelType: "gauge_long"},
	{Name: "RuleEvaluations", Stat: "Sum", DimSets: []DimSet{dimLB}, Source: srcConstZero, OTelType: "gauge_long"},
	{Name: "PeakLCUs", Stat: "Maximum", DimSets: []DimSet{dimLB}, Source: srcConstOne, OTelType: "gauge_long"},

	// --- HTTP status codes ---------------------------------------------------
	{Name: "HTTPCode_ELB_3XX_Count", Stat: "Sum", DimSets: []DimSet{dimLB, dimLBAZ}, Source: srcELB3XX, OTelType: "gauge_long"},
	{Name: "HTTPCode_ELB_4XX_Count", Stat: "Sum", DimSets: []DimSet{dimLB, dimLBAZ}, Source: srcELB4XX, OTelType: "gauge_long"},
	{Name: "HTTPCode_ELB_5XX_Count", Stat: "Sum", DimSets: []DimSet{dimLB, dimLBAZ}, Source: srcELB5XX, OTelType: "gauge_long"},
	{Name: "HTTPCode_ELB_503_Count", Stat: "Sum", DimSets: []DimSet{dimLB, dimLBAZ}, Source: srcELB503, OTelType: "gauge_long"},
	{Name: "HTTPCode_Target_2XX_Count", Stat: "Sum", DimSets: []DimSet{dimLB, dimLBAZ, dimLBTG, dimLBAZTG}, Source: srcTgt2XX, OTelType: "gauge_long"},
	{Name: "HTTPCode_Target_3XX_Count", Stat: "Sum", DimSets: []DimSet{dimLB, dimLBAZ, dimLBTG, dimLBAZTG}, Source: srcTgt3XX, OTelType: "gauge_long"},
	{Name: "HTTPCode_Target_4XX_Count", Stat: "Sum", DimSets: []DimSet{dimLB, dimLBAZ, dimLBTG, dimLBAZTG}, Source: srcTgt4XX, OTelType: "gauge_long"},
	{Name: "HTTPCode_Target_5XX_Count", Stat: "Sum", DimSets: []DimSet{dimLB, dimLBAZ, dimLBTG, dimLBAZTG}, Source: srcTgt5XX, OTelType: "gauge_long"},
	{Name: "DesyncMitigationMode_NonCompliant_Request_Count", Stat: "Average", DimSets: []DimSet{dimLB, dimLBAZ}, Source: srcConstZero, OTelType: "gauge_long"},

	// --- Latency (omitted for windows with no target responses) -------------
	{Name: "TargetResponseTime", Stat: "Average", DimSets: []DimSet{dimLB, dimLBAZ, dimLBTG, dimLBAZTG}, Source: srcTargetResponseTimeAvg, OTelType: "gauge_double"},
	{Name: "TargetResponseTime", Stat: "Maximum", DimSets: []DimSet{dimLB, dimLBAZ, dimLBTG, dimLBAZTG}, Source: srcTargetResponseTimeMax, OTelType: "gauge_double"},

	// --- Target health -------------------------------------------------------
	// {LoadBalancer} alone is not an AWS-documented dimension set for these,
	// but the dashboards' health/status panels require it.
	{Name: "HealthyHostCount", Stat: "Average", DimSets: []DimSet{dimLB, dimLBTG, dimLBAZTG}, Source: srcHealthyHostCount, OTelType: "gauge_long"},
	{Name: "HealthyHostCount", Stat: "Maximum", DimSets: []DimSet{dimLB, dimLBTG, dimLBAZTG}, Source: srcHealthyHostCount, OTelType: "gauge_long"},
	{Name: "UnHealthyHostCount", Stat: "Average", DimSets: []DimSet{dimLB, dimLBTG, dimLBAZTG}, Source: srcUnHealthyHostCount, OTelType: "gauge_long"},
	{Name: "UnHealthyHostCount", Stat: "Maximum", DimSets: []DimSet{dimLB, dimLBTG, dimLBAZTG}, Source: srcUnHealthyHostCount, OTelType: "gauge_long"},
	{Name: "HealthyStateDNS", Stat: "Maximum", DimSets: []DimSet{dimLBTG, dimLBAZTG}, Source: srcHealthyStateDNS, OTelType: "gauge_long"},
	{Name: "HealthyStateRouting", Stat: "Maximum", DimSets: []DimSet{dimLBTG, dimLBAZTG}, Source: srcHealthyStateRouting, OTelType: "gauge_long"},
	{Name: "UnhealthyStateDNS", Stat: "Minimum", DimSets: []DimSet{dimLBTG, dimLBAZTG}, Source: srcUnhealthyStateDNS, OTelType: "gauge_long"},
	{Name: "UnhealthyStateRouting", Stat: "Minimum", DimSets: []DimSet{dimLBTG, dimLBAZTG}, Source: srcUnhealthyStateRouting, OTelType: "gauge_long"},
	{Name: "AnomalousHostCount", Stat: "Maximum", DimSets: []DimSet{dimLBTG, dimLBAZTG}, Source: srcConstZero, OTelType: "gauge_long"},
	{Name: "MitigatedHostCount", Stat: "Average", DimSets: []DimSet{dimLBTG, dimLBAZTG}, Source: srcConstZero, OTelType: "gauge_long"},
}
