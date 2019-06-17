FROM debian:stretch

RUN \
  useradd -r -s /bin/false varnishd

RUN echo "deb http://deb.debian.org/debian stretch main" >/etc/apt/sources.list
RUN echo "deb-src http://deb.debian.org/debian stretch main" >/etc/apt/sources.list
RUN echo "deb http://deb.debian.org/debian stretch main contrib non-free">/etc/apt/sources.list


# Install Varnish source build dependencies.
# RUN printf "deb http://archive.debian.org/debian/ jessie maindeb-src http://archive.debian.org/debian/ jessie maindeb http://security.debian.org jessie/updates maindeb-src http://security.debian.org jessie/updates main" > /etc/apt/sources.list

RUN \
  apt-get update && apt-get install -y --no-install-recommends \
  automake \
  build-essential \
  ca-certificates \
  curl \
  libedit-dev \
  libjemalloc-dev \
  libncurses-dev \
  libpcre3-dev \
  libtool \
  pkg-config \
  python-docutils \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Install Varnish from source, so that Varnish modules can be compiled and installed.
ENV VARNISH_VERSION=4.1.9
ENV VARNISH_SHA256SUM=22d884aad87e585ce5f3b4a6d33442e3a855162f27e48358c7c93af1b5f2fc87
RUN \
  apt-get update && \
  mkdir -p /usr/local/src && \
  cd /usr/local/src && \
  curl -sfLO https://varnish-cache.org/_downloads/varnish-$VARNISH_VERSION.tgz && \
  echo "${VARNISH_SHA256SUM} varnish-$VARNISH_VERSION.tgz" | sha256sum -c - && \
  tar -xzf varnish-$VARNISH_VERSION.tgz && \
  cd varnish-$VARNISH_VERSION && \
  ./autogen.sh && \
  ./configure && \
  make install && \
  rm ../varnish-$VARNISH_VERSION.tgz

COPY start-varnishd.sh /usr/local/bin/start-varnishd

ENV VARNISH_PORT 80
ENV VARNISH_MEMORY 4500m

EXPOSE 80
CMD ["start-varnishd"]
COPY default.vcl /etc/varnish/default.vcl
