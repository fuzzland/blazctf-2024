FROM ghcr.io/fuzzland/blaz-ctf-2024-server:latest as chroot

FROM gcr.io/paradigmxyz/ctf/kctf-challenge:latest

VOLUME [ "/chroot", "/tmp" ]
COPY --from=chroot / /chroot

# ideally in the future, we can skip the chowns, but for now Forge wants to write the cache and broadcast artifacts
COPY --chown=user:user . /chroot/home/user/challenge/

RUN touch /chroot/bin/kctf_restore_env && touch /chroot/environ

CMD kctf_setup && \
    kctf_persist_env && \
    kctf_drop_privs socat TCP-LISTEN:1337,reuseaddr,fork EXEC:"nsjail --config /nsjail.cfg -- /bin/kctf_restore_env /usr/local/bin/python3 -u challenge/challenge.py"
