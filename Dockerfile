FROM debian:stretch-slim as helm_artifact

RUN apt-get update && apt-get install -y wget && \
    wget https://storage.googleapis.com/kubernetes-helm/helm-v2.9.1-linux-amd64.tar.gz && \
    echo "56ae2d5d08c68d6e7400d462d6ed10c929effac929fedce18d2636a9b4e166ba helm-v2.9.1-linux-amd64.tar.gz" | sha256sum -c && \
    tar xf helm-v2.9.1-linux-amd64.tar.gz && \
    cp linux-amd64/helm /usr/local/bin && \
    rm -rf helm-v2.9.1-linux-amd64.tar.gz linux-amd64

ADD helm /build/
WORKDIR /build/

RUN helm init --client-only
RUN helm package *
ARG BUILD_ARTIFACTS_HELM_CHARTS=/build/*.tgz

# run stage
FROM scratch
