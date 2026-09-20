package com.example.sqlcommenter;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.annotation.Nullable;

import io.opentelemetry.api.baggage.Baggage;

public class SpanContextMetadata {
  private static final Logger logger = Logger.getLogger(SpanContextMetadata.class.getName());
  private static final String UTF8 = StandardCharsets.UTF_8.toString();

  private final String traceId;
  private final String spanId;
  private final byte traceOptions;
  private final String traceState;

  private SpanContextMetadata(
      String traceId, String spanId, byte traceOptions, @Nullable String traceState) {
    this.traceId = traceId;
    this.spanId = spanId;
    this.traceOptions = traceOptions;
    this.traceState = traceState;
  }

  public static SpanContextMetadata fromOpenTelemetryContext(
      io.opentelemetry.context.Context context,
      io.opentelemetry.api.trace.SpanContext spanContext) {
    if (spanContext == null || !spanContext.isValid()) {
      return null;
    }

    String traceId = spanContext.getTraceId();
    String spanId = spanContext.getSpanId();
    byte traceOptions = spanContext.getTraceFlags().asByte();

    io.opentelemetry.api.trace.TraceState traceState = spanContext.getTraceState();

    if (traceState.isEmpty()) {
      return new SpanContextMetadata(traceId, spanId, traceOptions, null);
    }

    ArrayList<String> pairsList = new ArrayList<>();
    Map<String, String> map = traceState.asMap();
    for (String key : map.keySet()) {
      if (key.isEmpty()) {
        continue;
      }

      try {
        String value = map.get(key);
        String encoded = URLEncoder.encode((String.format("%s=%s", key, value)), UTF8);
        pairsList.add(encoded);
      } catch (Exception e) {
        logger.log(Level.WARNING, "Exception when encoding Tracestate", e);
      }
    }

    String traceStateStr = String.join(",", pairsList);

    return new SpanContextMetadata(traceId, spanId, traceOptions, traceStateStr);
  }

  public String getTraceId() {
    return traceId;
  }

  public String getSpanId() {
    return spanId;
  }

  public byte getTraceOptions() {
    return traceOptions;
  }

  public String getTraceState() {
    return traceState;
  }
}
