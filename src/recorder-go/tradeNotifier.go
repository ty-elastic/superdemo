package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"os"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
)

func notify(context context.Context, trade *Trade) {
	context, span := otel.Tracer("notifier").Start(context, "notify")
	defer span.End()

	span.AddEvent("notifying...")

	jsonTrade, err := json.Marshal(trade)
	if err != nil {
		logger.WithContext(context).Warnf("failure to marshall trade: %s", err)
		return
	}

	client := http.Client{Transport: otelhttp.NewTransport(http.DefaultTransport)}

	apiUrl := os.Getenv("NOTIFIER_ENDPOINT")
	if apiUrl == "" {
		apiUrl = "http://notifier:5000/notify"
	}
	req, err := http.NewRequestWithContext(context, "POST", apiUrl, bytes.NewReader(jsonTrade))
	if err != nil {
		logger.WithContext(context).Warnf("failure to create http req: %s", err)
		return
	}

	res, err := client.Do(req)
	defer res.Body.Close()

	if err != nil {
		logger.WithContext(context).Warnf("notification error: %s", err)
	}
}
