FROM ubuntu:18.04
LABEL maintainer="frasergr"

ARG DEBIAN_FRONTEND="noninteractive"
ARG APT_MIRROR="archive.ubuntu.com"

ARG PLEXDRIVE_VERSION="5.1.0"
ARG PLATFORM_ARCH="amd64"

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV S6_KEEP_ENV=1

ENV LANG=C.UTF-8
ENV PS1="\u@\h:\w\\$ "

RUN \
  echo "**** install packages ****" && \
  apt update && \
  apt install -y \
	unzip \
	tzdata \
	git \
	curl \
	wget \
	cron \
	python3 \
	python3-dev \
	python3-numpy \
	python3-pil \
	build-essential \
	devscripts \
	pngnq \
	optipng

RUN \
 echo "**** add s6 overlay ****" && \
 OVERLAY_VERSION=$(curl -sX GET "https://api.github.com/repos/just-containers/s6-overlay/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]') && \
 curl -o /tmp/s6-overlay.tar.gz -L "https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-amd64.tar.gz" && \
 tar xfz /tmp/s6-overlay.tar.gz -C /

RUN \
  echo "**** add overviewer source ****" && \
  mkdir /map && \
  git clone --single-branch --branch master https://github.com/overviewer/Minecraft-Overviewer.git /overviewer

RUN \
  echo "**** add overviewer build dependencies ****" && \
  cd /overviewer && \
  curl -O https://raw.githubusercontent.com/python-pillow/Pillow/master/src/libImaging/Imaging.h; \
  curl -O https://raw.githubusercontent.com/python-pillow/Pillow/master/src/libImaging/ImagingUtils.h ; \
  curl -O https://raw.githubusercontent.com/python-pillow/Pillow/master/src/libImaging/ImPlatform.h

RUN \
  echo "**** build overviewer ****" && \
  cd /overviewer && \
  python3 setup.py build && \
  python3 overviewer.py --verbose --version

RUN \
  echo "**** create abc user ****" && \
  mkdir /config && \
  groupmod -g 1000 users && \
  useradd -u 911 -U -d /config -s /bin/false abc && \
  usermod -G users abc

RUN \
  echo "**** download client textures ****" && \
  MC_VERSION=$(curl -sX GET "https://launchermeta.mojang.com/mc/game/version_manifest.json" | python3 -c "import sys, json; print(json.load(sys.stdin)['latest']['release'])") && \
  wget https://overviewer.org/textures/${MC_VERSION} -O /config/textures.jar

RUN \
  echo "**** cleanup ****" && \
  apt-get purge -y \
        curl \
        unzip \
	git \
	build-essential \
	devscripts \
	wget && \
  apt-get clean autoclean && \
  apt-get autoremove -y && \
  rm -rf /tmp/* /var/lib/{apt,dpkg,cache,log}/

RUN \
  echo "**** crontab setup ****" && \
  (crontab -l 2>/dev/null; echo "* * * * * cd / && run-parts --report /config/cron/minute > /proc/1/fd/1") | crontab - && \
  (crontab -l 2>/dev/null; echo "0 * * * * cd / && run-parts --report /config/cron/hourly > /proc/1/fd/1") | crontab - && \
  (crontab -l 2>/dev/null; echo "0 2 * * * cd / && run-parts --report /config/cron/daily > /proc/1/fd/1") | crontab - && \
  (crontab -l 2>/dev/null; echo "0 5 * * 1 cd / && run-parts --report /config/cron/weekly > /proc/1/fd/1") | crontab - && \
  (crontab -l 2>/dev/null; echo "0 0 1 * * cd / && run-parts --report /config/cron/monthly > /proc/1/fd/1") | crontab -

COPY root/ /

ENTRYPOINT ["/init"]
