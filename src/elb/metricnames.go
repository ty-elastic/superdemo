package main

// sourceKind describes how a metric value is derived from a WindowSnapshot.
type sourceKind int

const (
	srcRequestCount          sourceKind = iota // total request count
	srcRequestCountPerTarget                   // per-backend count (fans out per backend)
	srcTgt2XX                                  // HTTP 2xx from backends
	srcTgt3XX                                  // HTTP 3xx from backends
	srcTgt4XX                                  // HTTP 4xx from backends
	srcELB3XX                                  // ELB-generated 3xx
	srcELB4XX                                  // ELB-generated 4xx
	srcELB5XX                                  // ELB-generated 5xx
	srcELB503                                  // ELB 503 (no healthy backend)
	srcTargetResponseTime                      // max backend response time (float64, seconds)
	srcProcessedBytes                          // total bytes in + out
	srcActiveConnectionCount                   // in-flight requests (gauge)
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
type metricDef struct {
	Name     string     // CloudWatch metric name
	Stat     string     // "Sum" | "Average" | "Maximum"
	DimSets  []DimSet   // dimension combinations to emit; AZ-bearing sets fan out per configured AZ
	Float    bool       // whether the metric value is float64 (TargetResponseTime)
	Source   sourceKind // how the value is derived
	OTelType string     // Elasticsearch OTel dynamic template name (e.g. "gauge_long", "gauge_double")
}

// metricDefs enumerates all AWS ApplicationELB metrics we emit, with the
// dimension sets prescribed by the AWS CloudWatch documentation.
var metricDefs = []metricDef{
	{
		Name:     "ActiveConnectionCount",
		Stat:     "Sum",
		DimSets:  []DimSet{dimLB, dimLBAZ},
		Source:   srcActiveConnectionCount,
		OTelType: "gauge_long",
	},
	{
		Name:     "AnomalousHostCount",
		Stat:     "Maximum",
		DimSets:  []DimSet{dimLBTG, dimLBAZTG},
		Source:   srcConstZero,
		OTelType: "gauge_long",
	},
	{
		Name:     "DesyncMitigationMode_NonCompliant_Request_Count",
		Stat:     "Average",
		DimSets:  []DimSet{dimLB, dimLBAZ},
		Source:   srcConstZero,
		OTelType: "gauge_long",
	},
	{
		Name:     "HTTPCode_ELB_3XX_Count",
		Stat:     "Sum",
		DimSets:  []DimSet{dimLB, dimLBAZ},
		Source:   srcELB3XX,
		OTelType: "gauge_long",
	},
	{
		Name:     "HTTPCode_ELB_4XX_Count",
		Stat:     "Sum",
		DimSets:  []DimSet{dimLB, dimLBAZ},
		Source:   srcELB4XX,
		OTelType: "gauge_long",
	},
	{
		Name:     "HTTPCode_ELB_503_Count",
		Stat:     "Sum",
		DimSets:  []DimSet{dimLB, dimLBAZ},
		Source:   srcELB503,
		OTelType: "gauge_long",
	},
	{
		Name:     "HTTPCode_ELB_5XX_Count",
		Stat:     "Sum",
		DimSets:  []DimSet{dimLB, dimLBAZ},
		Source:   srcELB5XX,
		OTelType: "gauge_long",
	},
	{
		Name:     "HTTPCode_Target_2XX_Count",
		Stat:     "Sum",
		DimSets:  []DimSet{dimLB, dimLBAZ, dimLBTG, dimLBAZTG},
		Source:   srcTgt2XX,
		OTelType: "gauge_long",
	},
	{
		Name:     "HTTPCode_Target_3XX_Count",
		Stat:     "Sum",
		DimSets:  []DimSet{dimLB, dimLBAZ, dimLBTG, dimLBAZTG},
		Source:   srcTgt3XX,
		OTelType: "gauge_long",
	},
	{
		Name:     "HTTPCode_Target_4XX_Count",
		Stat:     "Sum",
		DimSets:  []DimSet{dimLB, dimLBAZ, dimLBTG, dimLBAZTG},
		Source:   srcTgt4XX,
		OTelType: "gauge_long",
	},
	{
		Name:     "HealthyHostCount",
		Stat:     "Average",
		DimSets:  []DimSet{dimLBTG, dimLBAZTG},
		Source:   srcHealthyHostCount,
		OTelType: "gauge_long",
	},
	{
		Name:     "HealthyStateDNS",
		Stat:     "Maximum",
		DimSets:  []DimSet{dimLBTG, dimLBAZTG},
		Source:   srcHealthyStateDNS,
		OTelType: "gauge_long",
	},
	{
		Name:     "HealthyStateRouting",
		Stat:     "Maximum",
		DimSets:  []DimSet{dimLBTG, dimLBAZTG},
		Source:   srcHealthyStateRouting,
		OTelType: "gauge_long",
	},
	{
		Name:     "MitigatedHostCount",
		Stat:     "Average",
		DimSets:  []DimSet{dimLBTG, dimLBAZTG},
		Source:   srcConstZero,
		OTelType: "gauge_long",
	},
	{
		Name:     "PeakLCUs",
		Stat:     "Maximum",
		DimSets:  []DimSet{dimLB},
		Source:   srcConstOne,
		OTelType: "gauge_long",
	},
	{
		Name:     "ProcessedBytes",
		Stat:     "Sum",
		DimSets:  []DimSet{dimLB, dimLBAZ},
		Source:   srcProcessedBytes,
		OTelType: "gauge_long",
	},
	{
		Name:     "RequestCount",
		Stat:     "Sum",
		DimSets:  []DimSet{dimLB, dimLBAZ, dimLBTG, dimLBAZTG},
		Source:   srcRequestCount,
		OTelType: "gauge_long",
	},
	{
		// Dimension sets without LoadBalancer ({TG} and {TG,AZ}) are also required per AWS docs.
		Name:     "RequestCountPerTarget",
		Stat:     "Sum",
		DimSets:  []DimSet{dimTG, dimTGAZ, dimLBTG, dimLBAZTG},
		Source:   srcRequestCountPerTarget,
		OTelType: "gauge_long",
	},
	{
		Name:     "RuleEvaluations",
		Stat:     "Sum",
		DimSets:  []DimSet{dimLB},
		Source:   srcConstZero,
		OTelType: "gauge_long",
	},
	{
		Name:     "TargetResponseTime",
		Stat:     "Average",
		Float:    true,
		DimSets:  []DimSet{dimLB, dimLBAZ, dimLBTG, dimLBAZTG},
		Source:   srcTargetResponseTime,
		OTelType: "gauge_double",
	},
	{
		Name:     "UnHealthyHostCount",
		Stat:     "Average",
		DimSets:  []DimSet{dimLBTG, dimLBAZTG},
		Source:   srcUnHealthyHostCount,
		OTelType: "gauge_long",
	},
	{
		Name:     "UnhealthyStateDNS",
		Stat:     "Minimum",
		DimSets:  []DimSet{dimLBTG, dimLBAZTG},
		Source:   srcUnhealthyStateDNS,
		OTelType: "gauge_long",
	},
	{
		Name:     "UnhealthyStateRouting",
		Stat:     "Minimum",
		DimSets:  []DimSet{dimLBTG, dimLBAZTG},
		Source:   srcUnhealthyStateRouting,
		OTelType: "gauge_long",
	},
}
