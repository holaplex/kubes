#!/bin/bash
set -e
git_branch="ryans/increased-limits"
repo_path="geyser-plugin"
git clone https://github.com/holaplex/indexer-geyser-plugin $repo_path || git --git-dir=$repo_path/.git pull
git --git-dir=$repo_path/.git checkout $git_branch
cat <<EOF>plugin.Dockerfile
FROM rust:1.58.1-slim-bullseye AS build
WORKDIR /build

RUN apt-get update -y && \
  apt-get install -y \
    libpq-dev \
    libssl-dev \
    libudev-dev \
    pkg-config \
  && \
  rm -rf /var/lib/apt/lists/*

COPY rust-toolchain.toml ./

# Force rustup to install toolchain
RUN rustc --version

COPY crates crates
COPY Cargo.toml Cargo.lock ./

RUN cargo build --profile docker \
-pholaplex-indexer-rabbitmq-geyser
RUN cp ./target/docker/libholaplex_indexer_rabbitmq_geyser.so /tmp
WORKDIR /tmp
EOF

docker build -t geyser-plugin-builder --file plugin.Dockerfile $repo_path
container_id=$(docker run -d geyser-plugin-builder:latest sleep 120)
docker cp $container_id:/tmp/libholaplex_indexer_rabbitmq_geyser.so .


#Get Pod name
#pod_name=$(kubectl get pods -n $namespace --no-headers | awk {'print $1'})
#Remove old plugin
#kubectl exec $pod_name -n $namespace -c validator -- rm /geyser/libholaplex_indexer_rabbitmq_geyser.so
#Copy new plugin build
#kubectl cp -c geyser-plugin-loader libholaplex_indexer_rabbitmq_geyser.so $namespace/$pod_name:/geyser
