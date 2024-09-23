FROM rust:1.80.1 AS chroot

ENV PATH="/home/user/.local/share/solana/install/active_release/bin:${PATH}"

RUN true && \
    useradd -u 1000 -m user && \
    apt-get update && \
    apt-get install -y libudev-dev make && \
    rm -rf /var/cache/apt/lists /var/lib/apt/lists/* && \
    true

USER user
WORKDIR /home/user

RUN true && \
    curl -L https://release.anza.xyz/v1.18.23/install | bash && \
    true

COPY --chown=user:user server /home/user/server

RUN true && \
    cd /home/user/server/program && \
    make && \
    cd /home/user/server && \
    cargo build --release && \
    true

FROM ubuntu:22.04 AS intermediate

RUN true && \
    useradd -u 1000 -m user && \
    true

USER user
WORKDIR /home/user

COPY --chown=user:user server /home/user/server

COPY --from=chroot /home/user/server/program/build/solalloc.so /home/user/server/solalloc.so
COPY --from=chroot /home/user/server/target/release/server /home/user/server/bin

FROM gcr.io/paradigmxyz/ctf/kctf-challenge:latest

VOLUME [ "/chroot", "/tmp" ]

COPY --from=intermediate / /chroot

# nsjail help
RUN touch /chroot/bin/kctf_restore_env && touch /chroot/environ

CMD kctf_setup && \
    kctf_persist_env && \
    kctf_drop_privs \
    nsjail --config /nsjail.cfg -- /bin/kctf_restore_env /home/user/server/bin & \
    kctf_drop_privs socat TCP-LISTEN:1337,reuseaddr,fork EXEC:'kctf_pow "socat STDIO TCP:127.0.0.1:31337"'
