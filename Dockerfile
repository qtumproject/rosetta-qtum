# Copyright 2020 Coinbase, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Build bitcoind
FROM ubuntu:20.04 as qtumd-builder

RUN mkdir -p /app \
  && chown -R nobody:nogroup /app
WORKDIR /app

# Source: https://github.com/bitcoin/bitcoin/blob/master/doc/build-unix.md#ubuntu--debian
#RUN apt-get update && apt-get install -y make gcc g++ autoconf autotools-dev bsdmainutils build-essential git libboost-all-dev \
#  libcurl4-openssl-dev libdb++-dev libevent-dev libssl-dev libtool pkg-config python python-pip libzmq3-dev wget


#ADD http://198.211.122.66/qtumd /app/qtumd

ENV QTUM_RELEASE_URL https://github.com/qtumproject/qtum/releases/download/mainnet-fastlane-v0.20.3
ENV QTUM_ARCHIVE qtum-0.20.3-x86_64-linux-gnu.tar.gz
ENV QTUM_FOLDER qtum-0.20.3

ADD $QTUM_RELEASE_URL/$QTUM_ARCHIVE ./
RUN tar -xzf $QTUM_ARCHIVE \
&& rm $QTUM_ARCHIVE \
&& mv $QTUM_FOLDER/bin/qtumd /app/qtumd \
&& rm -rf $QTUM_FOLDER


# Build Rosetta Server Components
FROM ubuntu:20.04 as rosetta-builder

RUN mkdir -p /app \
  && chown -R nobody:nogroup /app
WORKDIR /app

RUN apt-get update && apt-get install -y curl make gcc g++
# Install Golang 1.17.5.
ENV GOLANG_VERSION 1.17.5
ENV GOLANG_DOWNLOAD_URL https://golang.org/dl/go$GOLANG_VERSION.linux-amd64.tar.gz
ENV GOLANG_DOWNLOAD_SHA256 bd78114b0d441b029c8fe0341f4910370925a4d270a6a590668840675b0c653e

RUN curl -fsSL "$GOLANG_DOWNLOAD_URL" -o golang.tar.gz \
  && echo "$GOLANG_DOWNLOAD_SHA256  golang.tar.gz" | sha256sum -c - \
  && tar -C /usr/local -xzf golang.tar.gz \
  && rm golang.tar.gz

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

# Use native remote build context to build in any directory
COPY . src 
RUN cd src \
  && go build \
  && cd .. \
  && mv src/rosetta-qtum /app/rosetta-qtum \
  && mv src/assets/* /app \
  && rm -rf src 

## Build Final Image
FROM ubuntu:20.04

RUN apt-get update && \
  DEBIAN_FRONTEND="noninteractive" apt-get install --no-install-recommends -y libevent-dev libboost-system-dev libboost-filesystem-dev libboost-test-dev libboost-thread-dev libboost-all-dev libgmp-dev && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /app \
  && chown -R nobody:nogroup /app \
  && mkdir -p /data \
  && chown -R nobody:nogroup /data

WORKDIR /app

# Copy binary from qtumd-builder
COPY --from=qtumd-builder /app/qtumd /app/qtumd

# Copy binary from rosetta-builder
COPY --from=rosetta-builder /app/* /app/

# Set permissions for everything added to /app
RUN chmod -R 755 /app/*

CMD ["/app/rosetta-qtum"]
