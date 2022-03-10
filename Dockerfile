FROM golang:1.17 as builder

ARG VERSION
ARG GIT_COMMITSHA
WORKDIR /build
# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download
# Copy the go source
COPY main.go main.go
COPY internal/ internal/
COPY perf/ perf/
# Build
COPY build/ build/
RUN GOPROXY=https://proxy.golang.org,direct CGO_ENABLED=1 GOOS=linux GOARCH=amd64 GO111MODULE=on go build -ldflags="-w -s -X main.version=$VERSION -X main.gitsha=$GIT_COMMITSHA" -a -o meshery-perf main.go

FROM alpine:3.15 as jsonschema-util
RUN apk add --no-cache curl
WORKDIR /
RUN curl -LO https://github.com/layer5io/kubeopenapi-jsonschema/releases/download/v0.1.3/kubeopenapi-jsonschema
RUN chmod +x /kubeopenapi-jsonschema

# Use distroless as minimal base image to package the manager binary
# Refer to https://github.com/GoogleContainerTools/distroless for more details
FROM gcr.io/distroless/nodejs:16
ENV DISTRO="debian"
ENV GOARCH="amd64"
ENV SERVICE_ADDR="meshery-perf"
ENV MESHERY_SERVER="http://meshery:9081"
COPY templates/ ./templates
WORKDIR /
COPY --from=builder /build/meshery-perf .
COPY --from=jsonschema-util /kubeopenapi-jsonschema /root/.meshery/bin/kubeopenapi-jsonschema
ENTRYPOINT ["/meshery-perf"]