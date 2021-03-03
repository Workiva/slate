FROM debian:stretch-slim as helm_artifact

RUN apt-get update && apt-get install -y wget && \
    wget https://get.helm.sh/helm-v3.2.1-linux-amd64.tar.gz && \
    echo "018f9908cb950701a5d59e757653a790c66d8eda288625dbb185354ca6f41f6b helm-v3.2.1-linux-amd64.tar.gz" | sha256sum -c && \
    tar xf helm-v3.2.1-linux-amd64.tar.gz && \
    cp linux-amd64/helm /usr/local/bin && \
    rm -rf helm-v3.2.1-linux-amd64.tar.gz linux-amd64

ADD helm /build/
WORKDIR /build/

RUN helm package *
ARG BUILD_ARTIFACTS_HELM_CHARTS=/build/*.tgz

# run stage
FROM scratch
