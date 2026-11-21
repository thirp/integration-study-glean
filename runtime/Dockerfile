FROM debian:trixie-slim AS download
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl
WORKDIR /release
RUN curl -fsSL --retry 3 https://github.com/thirp/runtime/releases/download/v0.16.11/thirp-runtime-linux-x86_64-0.16.11.tar.gz -o runtime.tar.gz \
 && echo '709b57b4fa5ee608fe8cfba754eff519acc983c97120c697b860a5bde33a70e0  runtime.tar.gz' | sha256sum -c - \
 && tar xzf runtime.tar.gz --strip-components=1 \
 && chmod +x thirp-agent thirp-broker thirp-connect
FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends libssl3t64 && rm -rf /var/lib/apt/lists/*
COPY --from=download /release/thirp-agent /release/thirp-broker /release/thirp-connect /usr/local/bin/
COPY --from=download /release/LICENSE /release/NOTICE /usr/share/doc/thirp/
