FROM ghcr.io/fuzzland/blaz-ctf-2024-rust-builder:latest as rust-builder

WORKDIR /build

ADD . .
RUN ./build.sh

# artifacts: 
# - /build/anvil
# - /build/jit-compiler
# - /build/libjit_dummy.o

FROM debian:trixie-slim

RUN apt update && apt install -y build-essential

COPY --from=rust-builder /build/anvil /usr/local/bin/anvil
COPY --from=rust-builder /build/jit-compiler /opt/jit-compiler
COPY --from=rust-builder /build/libjit_dummy.o /tmp/libjit_dummy.o