FROM debian:trixie-slim as rust-builder

RUN apt update && apt install -y wget git curl build-essential

# install rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly
ENV PATH="/root/.cargo/bin:${PATH}"

# install llvm-18
RUN apt -y install lsb-release wget software-properties-common gnupg
RUN curl --proto '=https' --tlsv1.2 -sSf https://apt.llvm.org/llvm.sh | bash
RUN apt -y install libpolly-18-dev libzstd-dev libz-dev
RUN ln -s /usr/bin/llvm-config-18 /usr/bin/llvm-config && ln -s /usr/bin/clang-18 /usr/bin/clang

WORKDIR /build
