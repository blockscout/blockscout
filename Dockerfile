# This dockerfile will combine all the stuff needed by blockscout
# into a single docker image for puppeth usage.
# Components include: local geth, postgres.

# Build go-ethereum
FROM ethereum/client-go:latest as gethbuilder

# Build postgres && blockscout
FROM bitwalker/alpine-elixir-phoenix:1.13

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images and things like `apt-get update` won't be using
# old cached versions when the Dockerfile is built.
ENV REFRESHED_AT=2021-09-16

# 70 is the standard uid/gid for "postgres" in Alpine
# https://git.alpinelinux.org/aports/tree/main/postgresql/postgresql.pre-install?h=3.12-stable
RUN set -eux; \
	addgroup -g 70 -S postgres; \
	adduser -u 70 -S -D -G postgres -H -h /var/lib/postgresql -s /bin/sh postgres; \
	mkdir -p /var/lib/postgresql; \
	chown -R postgres:postgres /var/lib/postgresql

# su-exec (gosu-compatible) is installed further down

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
# alpine doesn't require explicit locale-file generation
ENV LANG en_US.utf8

RUN mkdir /docker-entrypoint-initdb.d

ENV PG_MAJOR 14
ENV PG_VERSION 14.1
ENV PG_SHA256 4d3c101ea7ae38982f06bdc73758b53727fb6402ecd9382006fa5ecc7c2ca41f

RUN set -eux; \
	\
	wget -O postgresql.tar.bz2 "https://ftp.postgresql.org/pub/source/v$PG_VERSION/postgresql-$PG_VERSION.tar.bz2"; \
	echo "$PG_SHA256 *postgresql.tar.bz2" | sha256sum -c -; \
	mkdir -p /usr/src/postgresql; \
	tar \
		--extract \
		--file postgresql.tar.bz2 \
		--directory /usr/src/postgresql \
		--strip-components 1 \
	; \
	rm postgresql.tar.bz2; \
	\
	apk add --no-cache --virtual .build-deps \
		bison \
		coreutils \
		dpkg-dev dpkg \
		flex \
		gcc \
		krb5-dev \
		libc-dev \
		libedit-dev \
		libxml2-dev \
		libxslt-dev \
		linux-headers \
		llvm-dev clang g++ \
		make \
		openldap-dev \
		openssl-dev \
# configure: error: prove not found
		perl-utils \
# configure: error: Perl module IPC::Run is required to run TAP tests
		perl-ipc-run \
		perl-dev \
		python3-dev \
		tcl-dev \
		util-linux-dev \
		zlib-dev \
# https://www.postgresql.org/docs/10/static/release-10.html#id-1.11.6.9.5.13
		icu-dev \
# https://www.postgresql.org/docs/14/release-14.html#id-1.11.6.5.5.3.7
		lz4-dev \
	; \
	\
	cd /usr/src/postgresql; \
# update "DEFAULT_PGSOCKET_DIR" to "/var/run/postgresql" (matching Debian)
# see https://anonscm.debian.org/git/pkg-postgresql/postgresql.git/tree/debian/patches/51-default-sockets-in-var.patch?id=8b539fcb3e093a521c095e70bdfa76887217b89f
	awk '$1 == "#define" && $2 == "DEFAULT_PGSOCKET_DIR" && $3 == "\"/tmp\"" { $3 = "\"/var/run/postgresql\""; print; next } { print }' src/include/pg_config_manual.h > src/include/pg_config_manual.h.new; \
	grep '/var/run/postgresql' src/include/pg_config_manual.h.new; \
	mv src/include/pg_config_manual.h.new src/include/pg_config_manual.h; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
# explicitly update autoconf config.guess and config.sub so they support more arches/libcs
	wget -O config/config.guess 'https://git.savannah.gnu.org/cgit/config.git/plain/config.guess?id=7d3d27baf8107b630586c962c057e22149653deb'; \
	wget -O config/config.sub 'https://git.savannah.gnu.org/cgit/config.git/plain/config.sub?id=7d3d27baf8107b630586c962c057e22149653deb'; \
# configure options taken from:
# https://anonscm.debian.org/cgit/pkg-postgresql/postgresql.git/tree/debian/rules?h=9.5
	./configure \
		--build="$gnuArch" \
# "/usr/src/postgresql/src/backend/access/common/tupconvert.c:105: undefined reference to `libintl_gettext'"
#		--enable-nls \
		--enable-integer-datetimes \
		--enable-thread-safety \
		--enable-tap-tests \
# skip debugging info -- we want tiny size instead
#		--enable-debug \
		--disable-rpath \
		--with-uuid=e2fs \
		--with-gnu-ld \
		--with-pgport=5432 \
		--with-system-tzdata=/usr/share/zoneinfo \
		--prefix=/usr/local \
		--with-includes=/usr/local/include \
		--with-libraries=/usr/local/lib \
		--with-krb5 \
		--with-gssapi \
		--with-ldap \
		--with-tcl \
		--with-perl \
		--with-python \
#		--with-pam \
		--with-openssl \
		--with-libxml \
		--with-libxslt \
		--with-icu \
		--with-llvm \
		--with-lz4 \
	; \
	make -j "$(nproc)" world; \
	make install-world; \
	make -C contrib install; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
# Remove plperl, plpython and pltcl dependencies by default to save image size
# To use the pl extensions, those have to be installed in a derived image
			| grep -v -e perl -e python -e tcl \
	)"; \
	apk add --no-cache --virtual .postgresql-rundeps \
		$runDeps \
		bash \
		su-exec \
# tzdata is optional, but only adds around 1Mb to image size and is recommended by Django documentation:
# https://docs.djangoproject.com/en/1.10/ref/databases/#optimizing-postgresql-s-configuration
		tzdata \
	; \
	apk del --no-network .build-deps; \
	cd /; \
	rm -rf \
		/usr/src/postgresql \
		/usr/local/share/doc \
		/usr/local/share/man \
	; \
	\
	postgres --version

# make the sample config easier to munge (and "correct by default")
RUN set -eux; \
	cp -v /usr/local/share/postgresql/postgresql.conf.sample /usr/local/share/postgresql/postgresql.conf.sample.orig; \
	sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/local/share/postgresql/postgresql.conf.sample; \
	grep -F "listen_addresses = '*'" /usr/local/share/postgresql/postgresql.conf.sample

RUN mkdir -p /var/run/postgresql && chown -R postgres:postgres /var/run/postgresql && chmod 2777 /var/run/postgresql

ENV PGDATA /var/lib/postgresql/data
# this 777 will be replaced by 700 at runtime (allows semi-arbitrary "--user" values)
RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA"
VOLUME /var/lib/postgresql/data

RUN wget https://raw.githubusercontent.com/docker-library/postgres/master/$PG_MAJOR/alpine/docker-entrypoint.sh -O /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

# We set the default STOPSIGNAL to SIGINT, which corresponds to what PostgreSQL
# calls "Fast Shutdown mode" wherein new connections are disallowed and any
# in-progress transactions are aborted, allowing PostgreSQL to stop cleanly and
# flush tables to disk, which is the best compromise available to avoid data
# corruption.
#
# Users who know their applications do not keep open long-lived idle connections
# may way to use a value of SIGTERM instead, which corresponds to "Smart
# Shutdown mode" in which any existing sessions are allowed to finish and the
# server stops when all sessions are terminated.
#
# See https://www.postgresql.org/docs/12/server-shutdown.html for more details
# about available PostgreSQL server shutdown signals.
#
# See also https://www.postgresql.org/docs/12/server-start.html for further
# justification of this as the default value, namely that the example (and
# shipped) systemd service files use the "Fast Shutdown mode" for service
# termination.
#
STOPSIGNAL SIGINT

RUN apk --no-cache --update add alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3 file qemu-x86_64 jq

ENV GLIBC_REPO=https://github.com/sgerrand/alpine-pkg-glibc \
    GLIBC_VERSION=2.30-r0 \
    PORT=4000 \
    MIX_ENV="prod" \
    SECRET_KEY_BASE="RMgI4C1HSkxsEjdhtGMfwAHfyT6CKWXOgzCboJflfSm4jeAlic52io05KB6mqzc5" \
    PATH="$HOME/.cargo/bin:${PATH}" \
    RUSTFLAGS="-C target-feature=-crt-static"

RUN set -ex && \
    apk --update add libstdc++ curl ca-certificates && \
    for pkg in glibc-${GLIBC_VERSION} glibc-bin-${GLIBC_VERSION}; \
        do curl -sSL ${GLIBC_REPO}/releases/download/${GLIBC_VERSION}/${pkg}.apk -o /tmp/${pkg}.apk; done && \
    apk add --allow-untrusted /tmp/*.apk && \
    rm -v /tmp/*.apk && \
    /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib


# Get Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ARG CACHE_EXCHANGE_RATES_PERIOD
ARG DISABLE_READ_API
ARG API_PATH
ARG NETWORK_PATH
ARG DISABLE_WEBAPP
ARG DISABLE_WRITE_API
ARG CACHE_ENABLE_TOTAL_GAS_USAGE_COUNTER
ARG WOBSERVER_ENABLED
ARG ADMIN_PANEL_ENABLED
ARG CACHE_ADDRESS_WITH_BALANCES_UPDATE_INTERVAL
ARG SOCKET_ROOT
ARG SESSION_COOKIE_DOMAIN
ARG MIXPANEL_TOKEN
ARG MIXPANEL_URL
ARG AMPLITUDE_API_KEY
ARG AMPLITUDE_URL

# Cache elixir deps
ADD mix.exs mix.lock ./
ADD apps/block_scout_web/mix.exs ./apps/block_scout_web/
ADD apps/explorer/mix.exs ./apps/explorer/
ADD apps/ethereum_jsonrpc/mix.exs ./apps/ethereum_jsonrpc/
ADD apps/indexer/mix.exs ./apps/indexer/

RUN mix do deps.get, local.rebar --force, deps.compile

ADD . .

COPY . .

# Run forderground build and phoenix digest
RUN mix compile && npm install npm@latest

# Add blockscout npm deps
RUN cd apps/block_scout_web/assets/ && \
    npm install && \
    npm run deploy && \
    cd /app/apps/explorer/ && \
    npm install && \
    apk update && \
    apk del --force-broken-world alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3

RUN mix phx.digest

RUN mkdir -p /opt/release \
  && mix release blockscout \
  && mv _build/${MIX_ENV}/rel/blockscout /opt/release

ENV PORT=4000 \
    ETHEREUM_JSONRPC_VARIANT="geth" \
    ETHEREUM_JSONRPC_HTTP_URL="http://localhost:8545" \
    ETHEREUM_JSONRPC_WS_URL="ws://localhost:8546" \ 
    DATABASE_URL="postgresql://postgres:@localhost:5432/blockscout?ssl=false" \
    POSTGRES_PASSWORD=\
    POSTGRES_USER=postgres\
    SUBNETWORK=\
    COIN="ETH"\
    POSTGRES_HOST_AUTH_METHOD="trust"\
    ECTO_USE_SSL=false

##############################################################

COPY --from=gethbuilder /usr/local/bin/geth /usr/local/bin

EXPOSE 5432 4000

