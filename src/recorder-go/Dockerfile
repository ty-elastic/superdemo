FROM golang:1.25 AS builder
WORKDIR /usr/src/app/

COPY go.* ./
COPY *.go ./
COPY lib lib
RUN --mount=type=cache,target=/root/.cache/go-build go build -o /go/bin/recorder

# -----------------------------------------------------------------------------

FROM golang:1.25

WORKDIR /usr/src/app/

COPY --from=builder /go/bin/recorder /usr/src/app/recorder

ENV OTEL_SERVICE_NAME="recorder-go"
ENV OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
ENV OTEL_EXPORTER_OTLP_INSECURE=true

EXPOSE 9003
CMD [ "/usr/src/app/recorder" ]
