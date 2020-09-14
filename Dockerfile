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

# swagger gen stage
FROM openjdk:8u212-slim as swagger-builder

# use the common workdir
WORKDIR /local-build

# bring in the bash tooling
COPY tool tool

# install wget
RUN apt-get update && apt-get install -y wget zip unzip

# grab the codegen tool
RUN wget https://oss.sonatype.org/content/repositories/releases/io/swagger/swagger-codegen-cli/2.2.1/swagger-codegen-cli-2.2.1.jar

# generate java client
RUN bash tool/generate_swagger.sh

#build stage
FROM ruby:2.6.3-alpine as builder

# bring in the code, cannot be at root, don't want name collision with middleman build dir (it's just confusing)
WORKDIR /local-build

# bring in the code
COPY . .

# install dependencies
RUN apk add --update nodejs nodejs-npm g++ make
RUN gem install bundler:2.0.2
RUN bundle install
RUN npm config set unsafe-perm true
RUN npm install -g widdershins@3.6.0

# generate documentation
RUN widdershins https://h.app.wdesk.com/s/cerebral/v2/api-docs -o source/includes/_swagger.md

# remove header from swagger, this is ugly but widdershins adds meta we don't need, the size of the meta (in lines) is deterministic so we know how many to remove
RUN tail -n +19 < source/includes/_swagger.md > source/includes/_swagger.md

# build the app which puts the compiled html, etc into the build directory
RUN bundle exec middleman build --clean

# Remove widdershins since we only need it on the container for building
RUN npm uninstall -g widdershins@3.6.0

# run stage
FROM amazonlinux:2

# add the NodeSource yum repository
RUN curl -sL https://rpm.nodesource.com/setup_14.x | bash -

#package updates
ARG BUILD_ID
RUN yum update -y && \
    yum upgrade -y && \
    yum autoremove -y && \
    yum install -y nodejs && \
    yum clean all && \
    rm -rf /var/cache/yum

RUN npm -version

# new workdir
WORKDIR /static/

# node config
RUN npm config set unsafe-perm true
RUN npm install http-server -g

RUN echo "http-server version"

RUN http-server --version

# create empty dependencies file... we have none but this is for rm
RUN touch npm.lock

# bring the static html in
COPY --from=builder /local-build/build/ s/cerebral-docs/

# bring in the generated clients
COPY --from=swagger-builder /local-build/source/generated/ s/cerebral-docs/generated/

# bring in gem lock
COPY --from=builder /local-build/Gemfile.lock /static/Gemfile.lock

# set dependency artifact
ARG BUILD_ARTIFACTS_AUDIT=/static/npm.lock:/static/Gemfile.lock

# run as non-root user
USER nobody

# open up port 8000
EXPOSE 8000

CMD ["http-server", "-p", "8000"]
