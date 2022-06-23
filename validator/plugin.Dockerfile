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
