FROM golang:1.23 AS lambda-env
WORKDIR /app
COPY ./pkg/lambda .
RUN GOOS=linux GOARCH=amd64 go build -o bootstrap .
RUN apt-get update && apt-get install -y zip
RUN mkdir -p artifacts && zip -j artifacts/lambda.zip bootstrap

FROM golang:1.14 AS build-env
RUN apt-get update -y
RUN apt-get install -y zip
RUN go get -u github.com/go-bindata/go-bindata/...

ADD . /src
WORKDIR /src
RUN mkdir -p artifacts
COPY --from=lambda-env app/artifacts/ ./artifacts/

RUN go-bindata -nocompress -pkg server -o pkg/server/bindata.go artifacts/lambda.zip
RUN cd /src && make build

FROM alpine:latest
COPY --from=build-env /src/artifacts/server/linux/awslambdaproxy /app/

ENV AWS_ACCESS_KEY_ID=
ENV AWS_SECRET_ACCESS_KEY=
ENV LAMBDA_NAME=
ENV LAMBDA_IAM_ROLE_NAME=
ENV REGIONS=
ENV FREQUENCY=
ENV MEMORY=
ENV SSH_USER=
ENV SSH_PORT=2222
ENV LISTENERS=
ENV DEBUG=
ENV DEBUG_PROXY=
ENV BYPASS=

WORKDIR /app

RUN addgroup -g 1000 -S ssh \
 && adduser -u 1000 -S ssh -G ssh \
 && apk add --no-cache openssh-server bash ca-certificates \
 && rm -rf /var/cache/apk/*

USER ssh

RUN mkdir ${HOME}/.ssh

EXPOSE 2222
EXPOSE 8080

COPY build/docker/sshd_config /etc/ssh/sshd_config
COPY build/docker/entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]