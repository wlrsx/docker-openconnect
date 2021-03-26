FROM alpine:latest

MAINTAINER MarkusMcNugen
# Forked from TommyLau for unRAID

VOLUME /config

# Install dependencies
RUN buildDeps=" \
		curl \
		g++ \
		gawk \
		gnutls-dev \
		gpgme \
		krb5-dev \
		libev-dev \
		libnl3-dev \
		libseccomp-dev \
		linux-headers \
		linux-pam-dev \
		lz4-dev \
		make \
		readline-dev \
		tar \
		xz \
	"; \
	set -x \
	&& apk add --update --virtual .build-deps $buildDeps \
	# The commented out line below grabs the most recent version of OC from the page which may be an unreleased version
	# && export OC_VERSION=$(curl --silent "https://ocserv.gitlab.io/www/changelog.html" 2>&1 | grep -m 1 'Version' | awk '/Version/ {print $2}') \
	# The line below grabs the 2nd most recent version of OC
	&& export OC_VERSION=$(curl --silent "https://ocserv.gitlab.io/www/changelog.html" 2>&1 | grep -m 2 'Version' | tail -n 1 | awk '/Version/ {print $2}') \
	&& curl -SL "ftp://ftp.infradead.org/pub/ocserv/ocserv-$OC_VERSION.tar.xz" -o ocserv.tar.xz \
	&& mkdir -p /usr/src/ocserv \
	&& tar -xf ocserv.tar.xz -C /usr/src/ocserv --strip-components=1 \
	&& rm ocserv.tar.xz* \
	&& cd /usr/src/ocserv \
	&& ./configure \
	&& make \
	&& make install \
	&& cd / \
	&& rm -rf /usr/src/ocserv \
	&& runDeps="$( \
			scanelf --needed --nobanner /usr/local/sbin/ocserv \
				| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
				| xargs -r apk info --installed \
				| sort -u \
			)" \
	&& apk add --virtual .run-deps $runDeps gnutls-utils iptables \
	&& apk del .build-deps \
	&& rm -rf /var/cache/apk/* 

RUN apk add --update bash rsync ipcalc sipcalc ca-certificates rsyslog logrotate runit
RUN update-ca-certificates

ADD ocserv /etc/default/ocserv

WORKDIR /config

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 4443
EXPOSE 4443/udp
CMD ["ocserv", "-c", "/config/ocserv.conf", "-f"]
