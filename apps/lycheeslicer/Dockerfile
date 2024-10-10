FROM ghcr.io/linuxserver/baseimage-kasmvnc:debianbookworm

# set version label
ARG BUILD_DATE
ARG VERSION
ARG LYCHEE_VERSION="7.0.1"
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thelamer"

# title
ENV TITLE=LycheeSlicer

RUN \
  echo "**** add icon ****" && \
  curl -o \
    /kclient/public/icon.png \
    https://raw.githubusercontent.com/lycheeverse/lychee-slicer/main/resources/images/lychee_logo.png && \
  echo "**** install packages ****" && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install --no-install-recommends -y \
    firefox-esr \
    wget && \
  echo "**** install Lychee Slicer ****" && \
  wget -O /tmp/lychee-slicer.deb \
    "https://mango-lychee.nyc3.digitaloceanspaces.com/LycheeSlicer-${LYCHEE_VERSION}.deb" && \
  dpkg -i /tmp/lychee-slicer.deb || apt-get -f install -y && \
  sed -i 's|</applications>|  <application title="Lychee Slicer" type="normal">\n    <maximized>yes</maximized>\n  </application>\n</applications>|' /etc/xdg/openbox/rc.xml && \
  echo "**** debugging: find Lychee Slicer executable ****" && \
  find / -name "lychee-slicer" 2>/dev/null && \
  echo "**** debugging: list contents of /usr/bin ****" && \
  ls -l /usr/bin | grep lychee && \
  echo "**** cleanup ****" && \
  apt-get autoclean && \
  rm -rf \
    /config/.cache \
    /config/.launchpadlib \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*

# add local files
COPY /root /

# ports and volumes
EXPOSE 3000
VOLUME /config
