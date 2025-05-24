# Makefile for a Rust project

# Change this to your actual binary name (the name in Cargo.toml [package].name)
BINARY = qkd_data_at_rest

.PHONY: all build run release run-release clean

all: build

build:
	cargo build

run: build
	./target/debug/$(BINARY)

release:
	cargo build --release

run-release: release
	./target/release/$(BINARY)

clean:
	cargo clean