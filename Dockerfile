# === Build stage ===
ARG ELIXIR_VERSION=1.20.2
ARG OTP_VERSION=28.1.1
ARG DEBIAN_VERSION=bookworm-20260610-slim
ARG NODE_VERSION=20

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

ARG NODE_VERSION

RUN for i in 1 2 3; do apt-get update -y && break || sleep 15; done && \
    for i in 1 2 3; do apt-get install -y build-essential git curl && break || sleep 15; done && \
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    for i in 1 2 3; do apt-get install -y nodejs && break || sleep 15; done && \
    npm install -g esbuild && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN npm install --prefix assets
RUN mix assets.setup
RUN mix assets.deploy

RUN mix compile

# Copy runtime config last so earlier layers are cached
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# === Runtime stage ===
FROM ${RUNNER_IMAGE}

RUN for i in 1 2 3; do apt-get update -y && break || sleep 15; done && \
    for i in 1 2 3; do apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates && break || sleep 15; done && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app

RUN chown nobody /app
ENV MIX_ENV=prod

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/craftplan ./
RUN find /app/bin -type f -exec sed -i 's/\r$//' {} +

USER nobody

CMD ["bin/server"]
