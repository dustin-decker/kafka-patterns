# Build stage
ARG GO_VERSION=1.10
ARG PROJECT_PATH=/go/src/github.com/dustin-decker/threatseer
FROM golang:${GO_VERSION}-alpine AS builder
RUN apk --no-cache add git ca-certificates curl
ADD https://github.com/golang/dep/releases/download/v0.4.1/dep-linux-amd64 /usr/bin/dep
RUN chmod +x /usr/bin/dep
RUN adduser -D -u 59999 container-user
RUN apk --no-cache add gcc pkgconfig
ARG LIBRESSL_VERSION=2.7
ARG LIBRDKAFKA_VERSION=0.11.4-r1

RUN apk update && \
    apk add libressl${LIBRESSL_VERSION}-libcrypto libressl${LIBRESSL_VERSION}-libssl --update-cache --repository http://nl.alpinelinux.org/alpine/edge/main && \
    apk add librdkafka=${LIBRDKAFKA_VERSION} --update-cache --repository http://nl.alpinelinux.org/alpine/edge/community && \
    apk add librdkafka-dev=${LIBRDKAFKA_VERSION} --update-cache --repository http://nl.alpinelinux.org/alpine/edge/community && \
    apk add git openssh openssl yajl-dev zlib-dev cyrus-sasl-dev openssl-dev build-base coreutils
# RUN apk add --no-cache  --repository http://dl-3.alpinelinux.org/alpine/edge/community/ \
#       bash  \
#       g++   \
#       git   \
#       libressl-dev  \
#       musl-dev  \
#       zlib-dev  \
#       wget  \
#       make
# RUN wget https://raw.githubusercontent.com/confluentinc/confluent-kafka-go/master/mk/bootstrap-librdkafka.sh
# RUN bash bootstrap-librdkafka.sh v0.11.4 tmp-build
WORKDIR /go/src/github.com/dustin-decker/kafka-patterns
COPY Gopkg.toml Gopkg.lock ./
RUN dep ensure --vendor-only
COPY ./ ${PROJECT_PATH}
RUN export PATH=$PATH:`go env GOHOSTOS`-`go env GOHOSTARCH` \
    && CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -tags static_all -o bin/kafka-patterns *.go \
    && go test $(go list ./... | grep -v /vendor/)

# Production image
FROM scratch
EXPOSE 8081
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /go/src/github.com/dustin-decker/kafka-patterns/bin/kafka-patterns /bin/kafka-patterns
ENTRYPOINT ["/bin/kafka-patterns"]
