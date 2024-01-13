# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-ubuntu:jammy

# set version label
ARG BUILD_DATE
ARG VERSION
ARG JELLYFIN_RELEASE

ARG SOURCE_DIR=/ffmpeg
ARG ARTIFACT_DIR=/dist
ARG BUILD_ARCHITECTURE=amd64
# Docker run environment
#GCC_VER=10
#LLVM_VER=13
ENV ARCH=${BUILD_ARCHITECTURE}
#ENV DEB_BUILD_OPTIONS=noddebs
ENV DEBIAN_FRONTEND=noninteractive
#ENV GCC_VER=GCC_RELEASE_VERSION
#ENV LLVM_VER=LLVM_RELEASE_VERSION
ENV SOURCE_DIR=/ffmpeg
ENV ARTIFACT_DIR=/dist
ENV TARGET_DIR=/usr/lib/jellyfin-ffmpeg
ENV DPKG_INSTALL_LIST=${SOURCE_DIR}/debian/jellyfin-ffmpeg6.install
ENV PATH=${TARGET_DIR}/bin:${PATH}
ENV PKG_CONFIG_PATH=${TARGET_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH}
ENV LD_LIBRARY_PATH=${TARGET_DIR}/lib:${TARGET_DIR}/lib/mfx:${TARGET_DIR}/lib/xorg:${LD_LIBRARY_PATH}
ENV LDFLAGS="-Wl,-rpath=${TARGET_DIR}/lib -L${TARGET_DIR}/lib"
ENV CXXFLAGS="-I${TARGET_DIR}/include $CXXFLAGS"
ENV CPPFLAGS="-I${TARGET_DIR}/include $CPPFLAGS"
ENV CFLAGS="-I${TARGET_DIR}/include $CFLAGS"
LABEL build_version="vio Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="vio"

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"
ENV NVIDIA_DRIVER_CAPABILITIES="compute,video,utility"

RUN \
  echo "**** install ubuntu:jammy *****" && \
  curl -s https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | gpg --dearmor | tee /usr/share/keyrings/jellyfin.gpg >/dev/null && \
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/jellyfin.gpg] https://repo.jellyfin.org/ubuntu jammy main' > /etc/apt/sources.list.d/jellyfin.list && \
  if [ -z ${JELLYFIN_RELEASE+x} ]; then \
    JELLYFIN_RELEASE=$(curl -sX GET https://repo.jellyfin.org/ubuntu/dists/jammy/main/binary-amd64/Packages | grep -A 7 -m 1 'Package: jellyfin-server' | awk -F ': ' '/Version/{print $2;exit}'); \
  fi && \
  apt-get update && \
  apt-get upgrade -y && \
  apt-get install -y autoconf libtool libdrm-dev git patch build-essential libargtable2-dev libargtable2-0 gawk wget libsdl1.2-dev libsdl1.2-dev cmake \
  apt-transport-https curl ninja-build debhelper gnupg wget devscripts mmv equivs git nasm pkg-config subversion dh-autoreconf libpciaccess-dev libwayland-dev libx11-dev \
  libx11-xcb-dev libxcb-dri2-0-dev libxcb-dri3-dev libxcb-present-dev libxcb-shm0-dev libxcb-sync-dev libxshmfence-dev libxext-dev libxfixes-dev libxcb1-dev libxrandr-dev \
  libzstd-dev libelf-dev python3-pip zip unzip tar flex bison && \
  apt-get install -y --no-install-recommends \
    at \
    mesa-va-drivers \
    xmlstarlet

# jellyfin=${JELLYFIN_RELEASE} \
#  apt-get install -y jellyfin-ffmpeg6 && \

# Install newer tools from pip3
RUN pip3 install $(pip3 help install | grep -o "\-\-break-system-packages") --upgrade pip && \
 pip3 install $(pip3 help install | grep -o "\-\-break-system-packages") meson cmake mako jinja2

# Avoids timeouts when using git and disable the detachedHead advice
RUN git config --global http.postbuffer 524288000 && \
  git config --global advice.detachedHead false

# Link to docker-build script
#RUN ln -sf ${SOURCE_DIR}/docker-build.sh /docker-build.sh

#VOLUME ${ARTIFACT_DIR}/

#COPY . ${SOURCE_DIR}/

RUN apt-get install -y openssh-client

RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh
COPY ./id_rsa /root/.ssh/id_rsa
# RUN ls -l /root/.ssh/
# RUN cat /root/.ssh/id_rsa
RUN \
  chmod 600 /root/.ssh/id_rsa && \
  ssh-keyscan -t rsa -H github.com >> /root/.ssh/known_hosts && \
  echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
# RUN ssh -T -o StrictHostKeyChecking=no git@github.com || true

WORKDIR ${SOURCE_DIR}
RUN \
  git config --global core.compression 0 && \
  git config --global pack.windowsMemory 256m && \
  git clone git@github.com:viotemp1/jellyfin-ffmpeg.git ${SOURCE_DIR}
RUN ${SOURCE_DIR}/docker-build.sh

RUN echo ${TARGET_DIR}/lib/mfx > /etc/ld.so.conf.d/jellyfin-ffmpeg.conf && \
  echo ${TARGET_DIR}/lib >> /etc/ld.so.conf.d/jellyfin-ffmpeg.conf && \
  ldconfig

WORKDIR ${SOURCE_DIR}
RUN echo "**** install jellyfin-ffmpeg *****"
# --pkg-config-flags="--static" --enable-static --disable-shared
# --enable-libvpl / --enable-libmfx --enable-dxva2 
RUN \
  ./configure --disable-x86asm --enable-libvpl --enable-vaapi --enable-libdrm --enable-gpl --enable-runtime-cpudetect \
  --extra-libs="-lpthread -lm -lz -ldl" --enable-nonfree && \
  make --silent -j$(nproc) all && make install

RUN cp -fP libavdevice/libavdevice.so* ${TARGET_DIR}/lib/ && \
  cp -fP libavfilter/libavfilter.so.* ${TARGET_DIR}/lib/ && \
  cp -fP libavformat/libavformat.so.* ${TARGET_DIR}/lib/ && \
  cp -fP libavcodec/libavcodec.so.* ${TARGET_DIR}/lib/ && \
  cp -fP libswresample/libswresample.so.* ${TARGET_DIR}/lib/ && \
  cp -fP libswscale/libswscale.so.* ${TARGET_DIR}/lib/ && \
  cp -fP libavutil/libavutil.so.* ${TARGET_DIR}/lib/ && \
  cp -fP libpostproc/libpostproc.so.* ${TARGET_DIR}/lib/ && \
  ldconfig

RUN echo "**** install comskip *****"
#ENV ffmpeg_LIBS=/usr/lib/jellyfin-ffmpeg/lib
WORKDIR ${SOURCE_DIR}
RUN \
  wget --quiet http://prdownloads.sourceforge.net/argtable/argtable2-13.tar.gz && \
  tar xzf argtable2-13.tar.gz && \
  cd argtable2-13/ && \
  ./configure && make && make install

WORKDIR ${SOURCE_DIR}
RUN \
  git clone https://github.com/viotemp1/Comskip.git comskip && \
  cd comskip && \
  ./autogen.sh && \
  ./configure --bindir=/usr/bin --sysconfdir=/config/comskip --enable-donator && \
  make && make install

WORKDIR ${SOURCE_DIR}

RUN \
  echo "**** cleanup ****" && \
  apt-get --purge --yes autoremove && \
  apt-get clean && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    ${ARTIFACT_DIR}/* \
    ${SOURCE_DIR}/* \
    /root/.ssh


# ports
# EXPOSE 8096 8920

#ENTRYPOINT ["/bin/bash"]
ENTRYPOINT ["/bin/bash", “-c” "echo Welcome to comskip_qsv"]
