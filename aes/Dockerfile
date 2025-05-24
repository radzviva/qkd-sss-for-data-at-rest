# aes/Dockerfile

# 1) Build stage
FROM rust:1.64 as builder
WORKDIR /app
# copy your Cargo.toml and source
COPY Cargo.toml Cargo.lock ./
COPY src ./src
# build in release mode
RUN cargo build --release

# 2) Runtime stage
FROM debian:bullseye-slim
WORKDIR /app
# copy the compiled binary
COPY --from=builder /app/target/release/aes_encrypt ./
# AES module expects data under data/inbox and data/outbox
VOLUME ["/app/data/inbox", "/app/data/outbox"]

ENTRYPOINT ["./qkd_data_at_rest"]
