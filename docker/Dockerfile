# This dockerfile will combine all the stuff needed by blockscout
# into a single docker image for puppeth usage.
# Components include: local geth, postgres.

# Build go-ethereum
FROM alpine:3.7 as builder

RUN \
  apk add --update go git make gcc musl-dev linux-headers ca-certificates && \
  git clone --depth 1 https://github.com/ethereum/go-ethereum && \
  (cd go-ethereum && make geth) && \
  cp go-ethereum/build/bin/geth /geth && \
  apk del go git make gcc musl-dev linux-headers && \
  rm -rf /go-ethereum && rm -rf /var/cache/apk/*

# Build postgres && blockscout
FROM bitwalker/alpine-elixir-phoenix:latest

# alpine includes "postgres" user/group in base install
#   /etc/passwd:22:postgres:x:70:70::/var/lib/postgresql:/bin/sh
#   /etc/group:34:postgres:x:70:
# the home directory for the postgres user, however, is not created by default
# see https://github.com/docker-library/postgres/issues/274
RUN set -ex; \
	postgresHome="$(getent passwd postgres)"; \
	postgresHome="$(echo "$postgresHome" | cut -d: -f6)"; \
	[ "$postgresHome" = '/var/lib/postgresql' ]; \
	mkdir -p "$postgresHome"; \
	chown -R postgres:postgres "$postgresHome"

# su-exec (gosu-compatible) is installed further down

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
# alpine doesn't require explicit locale-file generation
ENV LANG en_US.utf8

RUN mkdir /docker-entrypoint-initdb.d

ENV PG_MAJOR 11
ENV PG_VERSION 11.1
ENV PG_SHA256 90815e812874831e9a4bf6e1136bf73bc2c5a0464ef142e2dfea40cda206db08

RUN set -ex \
	\
	&& apk add --no-cache --virtual .fetch-deps \
		ca-certificates \
		openssl \
		tar \
	\
	&& wget -O postgresql.tar.bz2 "https://ftp.postgresql.org/pub/source/v$PG_VERSION/postgresql-$PG_VERSION.tar.bz2" \
	&& echo "$PG_SHA256 *postgresql.tar.bz2" | sha256sum -c - \
	&& mkdir -p /usr/src/postgresql \
	&& tar \
		--extract \
		--file postgresql.tar.bz2 \
		--directory /usr/src/postgresql \
		--strip-components 1 \
	&& rm postgresql.tar.bz2 \
	\
	&& apk add --no-cache --virtual .build-deps \
		bison \
		coreutils \
		dpkg-dev dpkg \
		flex \
		gcc \
#		krb5-dev \
		libc-dev \
		libedit-dev \
		libxml2-dev \
		libxslt-dev \
		make \
#		openldap-dev \
		openssl-dev \
# configure: error: prove not found
		perl-utils \
# configure: error: Perl module IPC::Run is required to run TAP tests
		perl-ipc-run \
#		perl-dev \
#		python-dev \
#		python3-dev \
#		tcl-dev \
		util-linux-dev \
		zlib-dev \
		icu-dev \
	\
	&& cd /usr/src/postgresql \
# update "DEFAULT_PGSOCKET_DIR" to "/var/run/postgresql" (matching Debian)
# see https://anonscm.debian.org/git/pkg-postgresql/postgresql.git/tree/debian/patches/51-default-sockets-in-var.patch?id=8b539fcb3e093a521c095e70bdfa76887217b89f
	&& awk '$1 == "#define" && $2 == "DEFAULT_PGSOCKET_DIR" && $3 == "\"/tmp\"" { $3 = "\"/var/run/postgresql\""; print; next } { print }' src/include/pg_config_manual.h > src/include/pg_config_manual.h.new \
	&& grep '/var/run/postgresql' src/include/pg_config_manual.h.new \
	&& mv src/include/pg_config_manual.h.new src/include/pg_config_manual.h \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
# explicitly update autoconf config.guess and config.sub so they support more arches/libcs
	&& wget -O config/config.guess 'https://git.savannah.gnu.org/cgit/config.git/plain/config.guess?id=7d3d27baf8107b630586c962c057e22149653deb' \
	&& wget -O config/config.sub 'https://git.savannah.gnu.org/cgit/config.git/plain/config.sub?id=7d3d27baf8107b630586c962c057e22149653deb' \
# configure options taken from:
# https://anonscm.debian.org/cgit/pkg-postgresql/postgresql.git/tree/debian/rules?h=9.5
	&& ./configure \
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
		\
# these make our image abnormally large (at least 100MB larger), which seems uncouth for an "Alpine" (ie, "small") variant :)
#		--with-krb5 \
#		--with-gssapi \
#		--with-ldap \
#		--with-tcl \
#		--with-perl \
#		--with-python \
#		--with-pam \
		--with-openssl \
		--with-libxml \
		--with-libxslt \
		--with-icu \
	&& make -j "$(nproc)" world \
	&& make install-world \
	&& make -C contrib install \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
	&& apk add --no-cache --virtual .postgresql-rundeps \
		$runDeps \
		bash \
		su-exec \
# tzdata is optional, but only adds around 1Mb to image size and is recommended by Django documentation:
# https://docs.djangoproject.com/en/1.10/ref/databases/#optimizing-postgresql-s-configuration
		tzdata \
	&& cd / \
	&& rm -rf \
		/usr/src/postgresql \
		/usr/local/share/doc \
	&& find /usr/local -name '*.a' -delete

# make the sample config easier to munge (and "correct by default")
RUN sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/local/share/postgresql/postgresql.conf.sample

RUN mkdir -p /var/run/postgresql && chown -R postgres:postgres /var/run/postgresql && chmod 2777 /var/run/postgresql

ENV PGDATA /var/lib/postgresql/data
RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA" # this 777 will be replaced by 700 at runtime (allows semi-arbitrary "--user" values)
VOLUME /var/lib/postgresql/data

RUN wget https://github.com/docker-library/postgres/blob/master/$PG_MAJOR/alpine/docker-entrypoint.sh -O /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

# Build blockscout
RUN apk --no-cache --update add automake libtool inotify-tools autoconf

ENV PORT=4000 \
    MIX_ENV="prod" \
    SECRET_KEY_BASE="RMgI4C1HSkxsEjdhtGMfwAHfyT6CKWXOgzCboJflfSm4jeAlic52io05KB6mqzc5" \
    ETHEREUM_JSONRPC_VARIANT="geth" \
    ETHEREUM_JSONRPC_HTTP_URL="http://localhost:8545" \
    ETHEREUM_JSONRPC_WS_URL="ws://localhost:8546" \ 
    DATABASE_URL="postgresql://postgres:@localhost:5432/explorer?ssl=false" \
    POSTGRES_PASSWORD=\
    POSTGRES_USER=postgres\
    SUBNETWORK=

# Note: this is a build issue in original blockscout dockerfile
# see https://github.com/poanetwork/blockscout/issues/1200 for detail
# This is a temporary solution, will update when upstrem fix it.
ADD . . 

# Cache elixir deps
ADD mix.exs mix.lock ./
ADD apps/block_scout_web/mix.exs ./apps/block_scout_web/
ADD apps/explorer/mix.exs ./apps/explorer/
ADD apps/ethereum_jsonrpc/mix.exs ./apps/ethereum_jsonrpc/
ADD apps/indexer/mix.exs ./apps/indexer/

RUN HEX_HTTP_CONCURRENCY=4 HEX_HTTP_TIMEOUT=120 mix do deps.get, deps.compile

ADD . .

# Run forderground build and phoenix digest
RUN mix compile

# Add blockscout npm deps
RUN cd apps/block_scout_web/assets/ && \
    npm install && \
    npm run deploy 

RUN cd apps/explorer/ && \
    npm install && \
    apk del --force-broken-world automake libtool inotify-tools autoconf	

COPY --from=builder /geth /usr/local/bin

EXPOSE 4000

