# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=debian:trixie-slim
FROM ${BASE_IMAGE}

SHELL ["/bin/sh", "-exc"]

COPY raspberrypi-archive.asc /usr/share/keyrings/raspberrypi-archive.asc

RUN printf '%s\n' \
      'Types: deb' \
      'URIs: http://archive.raspberrypi.com/debian/' \
      'Suites: trixie' \
      'Components: main' \
      'Signed-By: /usr/share/keyrings/raspberrypi-archive.asc' \
      > /etc/apt/sources.list.d/raspi.sources \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      procps \
      rgpiod \
      rgpio-tools \
 && rgpiod -v \
 && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

EXPOSE 8889

ENTRYPOINT ["docker-entrypoint.sh"]
CMD []
