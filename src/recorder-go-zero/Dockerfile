FROM golang:1.25
WORKDIR /usr/src/app/

COPY go.* ./
COPY *.go ./
# RUN go mod init main
# RUN go mod tidy
RUN --mount=type=cache,target=/root/.cache/go-build go build -o /recorder-zero

EXPOSE 9003
ENTRYPOINT [ "/recorder-zero" ]
