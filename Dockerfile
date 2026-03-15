# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=badaix/raspios-lite:trixie
FROM ${BASE_IMAGE}

SHELL ["/bin/sh", "-exc"]

RUN apt-get update \
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
