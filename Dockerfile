FROM alpine:3.24

ARG \
  BUILD_DATE=now \
  VERSION=unknown \
  S6_OVERLAY_VERSION=3.2.3.2

# Docker sets TARGETARCH during multi-platform builds; default to amd64 for plain builds.
ARG TARGETARCH=amd64

LABEL \
  org.label-schema.maintainer="Sylvain Martin (sylvain@nforcer.com)" \
  org.label-schema.build-date="${BUILD_DATE}" \
  org.label-schema.version="${VERSION}" \
  org.label-schema.vcs-url="https://github.com/nforcer/k8s-alpine-baseimage" \
  org.label-schema.vcs-ref="${VERSION}" \
  org.label-schema.schema-version="1.0"
  
ENV \
    S6_LOGGING=1 \
    S6_VERBOSITY=1 \
    S6_FIX_ATTRS_HIDDEN=1 \
    S6_KILL_FINISH_MAXTIME=300000 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    TZ=America/New_York \
    ENABLE_CRON=false

RUN \
  echo "**** Installing alpine packages ****" \
  && apk add --quiet --no-cache tar xz alpine-release rxvt-unicode-terminfo shadow libc-utils apk-tools procps-ng \
     jq bind-tools openssl tzdata ca-certificates coreutils bash git wget curl findutils busybox \
  && rm -rf /var/cache/apk/*

RUN \
  case "${TARGETARCH}" in \
    amd64) S6_OVERLAY_ARCH=x86_64 ;; \
    arm64) S6_OVERLAY_ARCH=aarch64 ;; \
    arm)   S6_OVERLAY_ARCH=armhf ;; \
    386)   S6_OVERLAY_ARCH=i686 ;; \
    *)     echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
  esac \
  && echo "**** Downloading S6 overlay v${S6_OVERLAY_VERSION} for ${S6_OVERLAY_ARCH} ****" \
  && mkdir -p /tmp/s6 && cd /tmp/s6 \
  && curl --location --silent --fail https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz -o s6-overlay-noarch.tar.xz \
  && curl --location --silent --fail https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz -o s6-overlay-arch.tar.xz \
  && curl --location --silent --fail https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz -o s6-overlay-symlinks-noarch.tar.xz \
  && curl --location --silent --fail https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz -o s6-overlay-symlinks-arch.tar.xz \
  && echo "**** Extracting S6 overlay ****" \
  && tar -C / -Jxp -f s6-overlay-noarch.tar.xz \
  && tar -C / -Jxp -f s6-overlay-arch.tar.xz \
  && tar -C / -Jxp -f s6-overlay-symlinks-noarch.tar.xz \
  && tar -C / -Jxp -f s6-overlay-symlinks-arch.tar.xz \
  && rm -rf /tmp/s6

COPY --chmod=755 /content/etc/s6-overlay /etc/s6-overlay

ENTRYPOINT [ "/init" ]
#CMD /bin/ash