package main

import (
	"context"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"
)

const flushInterval = 5 * time.Second

// RunLogFlusher drains access-log buffers from all load balancers and sends
// them to Elasticsearch every 5 seconds. It performs a final flush on shutdown.
// wg.Done() is called when the goroutine exits.
func RunLogFlusher(ctx context.Context, wg *sync.WaitGroup, lbs []*LoadBalancer, es *ESClient, datastream string) {
	defer wg.Done()
	ticker := time.NewTicker(flushInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			flushLogs(lbs, es, datastream)
		case <-ctx.Done():
			flushLogs(lbs, es, datastream) // final flush before exit
			return
		}
	}
}

func flushLogs(lbs []*LoadBalancer, es *ESClient, datastream string) {
	var all []BulkDoc
	for _, lb := range lbs {
		for _, body := range lb.logBuf.Drain() {
			all = append(all, BulkDoc{Body: body})
		}
	}
	if len(all) == 0 {
		return
	}
	if err := es.Bulk(datastream, all); err != nil {
		log.WithError(err).WithField("count", len(all)).Error("access log flush failed")
	} else {
		log.WithField("count", len(all)).Debug("flushed access logs")
	}
}

// RunMetricFlusher snapshots metrics from all load balancers, builds metric docs,
// and sends them to Elasticsearch every 5 seconds. It performs a final flush on shutdown.
func RunMetricFlusher(ctx context.Context, wg *sync.WaitGroup, lbs []*LoadBalancer, es *ESClient, datastream string, cfg *Config, hostName string) {
	defer wg.Done()
	ticker := time.NewTicker(flushInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			flushMetrics(lbs, es, datastream, cfg, hostName)
		case <-ctx.Done():
			flushMetrics(lbs, es, datastream, cfg, hostName) // final flush before exit
			return
		}
	}
}

func flushMetrics(lbs []*LoadBalancer, es *ESClient, datastream string, cfg *Config, hostName string) {
	now := time.Now().UTC()
	var all []BulkDoc
	for _, lb := range lbs {
		all = append(all, buildMetricDocs(lb, now, cfg, hostName)...)
	}
	if len(all) == 0 {
		return
	}
	if err := es.Bulk(datastream, all); err != nil {
		log.WithError(err).WithField("count", len(all)).Error("metric flush failed")
	} else {
		log.WithField("count", len(all)).Debug("flushed metrics")
	}
}

// buildMetricDocs snapshots lb's aggregator and produces metric docs for all metric defs.
// Each metric is emitted once per dimension set defined on it; sets that include
// AvailabilityZone are further fanned out once per configured AZ. Metrics with no
// value for the window (e.g. TargetResponseTime with no responses) are omitted,
// matching CloudWatch, which publishes no datapoint in that case.
func buildMetricDocs(lb *LoadBalancer, now time.Time, cfg *Config, hostName string) []BulkDoc {
	snap := lb.agg.Snapshot(lb.pool)

	azs := cfg.Resource.AvailabilityZones
	if len(azs) == 0 {
		azs = []string{""} // emit once without an AZ dimension
	}

	var docs []BulkDoc
	for _, def := range metricDefs {
		value := valueFromSnapshot(def, snap)
		if value == nil {
			continue
		}
		for _, dims := range def.DimSets {
			azList := []string{""}
			if dims.HasAZ {
				azList = azs
			}
			for _, az := range azList {
				p := MetricDocParams{
					Now:            now,
					WindowDuration: flushInterval,
					Def:            def,
					Dims:           dims,
					LoadBalancer:   lb.cfg.Name,
					TargetGroup:    lb.cfg.TargetGroup,
					AZ:             az,
					CloudAccountID: cfg.Resource.CloudAccountID,
					CloudRegion:    cfg.Resource.CloudRegion,
					HostName:       hostName,
					MetricValue:    value,
				}
				if doc, err := BuildMetricDoc(p); err == nil {
					docs = append(docs, doc)
				}
			}
		}
	}
	return docs
}

// valueFromSnapshot derives the numeric metric value (int64 or float64) for def
// from snap. It returns nil when the metric has no datapoint for this window.
func valueFromSnapshot(def metricDef, snap WindowSnapshot) interface{} {
	switch def.Source {
	case srcRequestCount:
		return snap.RequestCount
	case srcRequestCountPerTarget:
		// AWS: requests routed to the target group / number of healthy targets.
		healthy := int64(snap.HealthyHosts)
		if healthy < 1 {
			healthy = 1
		}
		return (snap.TargetRequests + healthy/2) / healthy
	case srcTgt2XX:
		return snap.Tgt2XX
	case srcTgt3XX:
		return snap.Tgt3XX
	case srcTgt4XX:
		return snap.Tgt4XX
	case srcTgt5XX:
		return snap.Tgt5XX
	case srcELB3XX:
		return snap.ELB3XX
	case srcELB4XX:
		return snap.ELB4XX
	case srcELB5XX:
		return snap.ELB5XX
	case srcELB503:
		return snap.ELB503
	case srcTargetResponseTimeAvg:
		if snap.TRTCount == 0 {
			return nil
		}
		return snap.TRTSum / float64(snap.TRTCount)
	case srcTargetResponseTimeMax:
		if snap.TRTCount == 0 {
			return nil
		}
		return snap.TRTMax
	case srcProcessedBytes:
		return snap.ProcessedBytes
	case srcActiveConnectionCount:
		return snap.ActiveConnections
	case srcNewConnectionCount:
		return snap.NewConnections
	case srcHealthyHostCount:
		return int64(snap.HealthyHosts)
	case srcUnHealthyHostCount:
		return int64(snap.UnhealthyHosts)
	case srcHealthyStateDNS, srcHealthyStateRouting:
		if snap.HealthyHosts > 0 {
			return int64(1)
		}
		return int64(0)
	case srcUnhealthyStateDNS, srcUnhealthyStateRouting:
		if snap.UnhealthyHosts > 0 {
			return int64(1)
		}
		return int64(0)
	case srcConstZero:
		return int64(0)
	case srcConstOne:
		return int64(1)
	default:
		return int64(0)
	}
}
