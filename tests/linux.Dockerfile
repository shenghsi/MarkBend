FROM oven/bun:1.3.11@sha256:0733e50325078969732ebe3b15ce4c4be5082f18c4ac1a0f0ca4839c2e4e42a7 AS bun
FROM ubuntu:24.04

RUN apt-get update -o Acquire::By-Hash=force -qq && \
    apt-get install -y -qq clang curl ca-certificates git nodejs libx11-dev time

ARG TARGETARCH
# Release hashes from the Bend 2.0.34 installer. Do not use a moving installer.
RUN case "$TARGETARCH" in \
      arm64) bend_arch=arm64; bend_sha=416a17d282a9fd05ab9637a238b51d5ca508114d9773c37d1c11cad595440ed1 ;; \
      amd64) bend_arch=x64; bend_sha=78106a97af242429dcc057258eb8d10f69cddebcd5e263022185a52d003e09bf ;; \
      *) exit 1 ;; \
    esac && \
    curl --proto '=https' --tlsv1.2 -fsSL \
      "https://github.com/bendlang/bend/releases/download/v2.0.34/bend-2.0.34-linux-$bend_arch.tar.gz" \
      -o /tmp/bend-release.tar.gz && \
    printf '%s  /tmp/bend-release.tar.gz\n' "$bend_sha" | sha256sum -c - && \
    tar -xzf /tmp/bend-release.tar.gz -C /opt

ENV PATH="/opt/bend/bin:${PATH}"
COPY --from=bun /usr/local/bin/bun /usr/local/bin/bun
RUN test "$(bun --version)" = "1.3.11"
ENV BEND_NO_TELEMETRY=1
ENV GIT_CONFIG_COUNT=1
ENV GIT_CONFIG_KEY_0=safe.directory
ENV GIT_CONFIG_VALUE_0=/tmp/markbend

CMD ["sh", "-c", "cp -a /work /tmp/markbend && cd /tmp/markbend && bend guide >/tmp/bend-guide.txt && sh tests/check.sh"]
