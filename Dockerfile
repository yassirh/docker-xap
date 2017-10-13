FROM openjdk:8-jdk-slim
# JDK is needed to execute GS Webui

ENV XAP_VERSION 12.1.1
ENV XAP_BUILD_NUMBER 17100
ENV XAP_MILESTONE ga
ENV XAP_HOME_DIR /opt/xap

# Download XAP
ENV XAP_DOWNLOAD_URL https://gigaspaces-repository-eu.s3.amazonaws.com/com/gigaspaces/xap/${XAP_VERSION}/${XAP_VERSION}/gigaspaces-xap-premium-${XAP_VERSION}-${XAP_MILESTONE}-b${XAP_BUILD_NUMBER}.zip

ENV BUILD_PACKAGES=curl

RUN set -ex \
    && apt-get update && apt-get install -y \
           $BUILD_PACKAGES \
    && curl -fSL "${XAP_DOWNLOAD_URL}" -o /tmp/xap.zip \
    && unzip /tmp/xap.zip -d /tmp/xap_unzip \
    && mv /tmp/xap_unzip/gigaspaces-xap-premium-${XAP_VERSION}-${XAP_MILESTONE}-b${XAP_BUILD_NUMBER} $XAP_HOME_DIR \
    && rm -rf \
        /tmp/xap.zip \
        /tmp/xap_unzip \
        ${XAP_HOME_DIR}/{examples,tools}/ \
        ${XAP_HOME_DIR}/START_HERE.htm \
        ${XAP_HOME_DIR}/NOTICE.md \
    && apt-get remove --purge -y $BUILD_PACKAGES \
    && rm -rf /var/lib/apt/lists/*

ENV XAP_NIC_ADDRESS "#eth0:ip#"
ENV EXT_JAVA_OPTIONS "-Dcom.gs.multicast.enabled=false -Dcom.gs.multicast.discoveryPort=4174 -Dcom.gs.transport_protocol.lrmi.bind-port=10000-10100 -Dcom.gigaspaces.start.httpPort=9104 -Dcom.gigaspaces.system.registryPort=7102"
ENV XAP_GSM_OPTIONS "-Xms128m -Xmx128m"
ENV XAP_GSC_OPTIONS "-Xms128m -Xmx128m"
ENV XAP_LOOKUP_GROUPS xap

# GS webui
ENV XAP_WEBUI_OPTIONS "${EXT_JAVA_OPTIONS}"
ENV WEBUI_PORT 8099

RUN set -ex \
    && apt-get update && apt-get install -y \
		apache2 \
        curl \
        gnupg \
        netcat-openbsd \
        procps \
		vim

RUN curl -sL https://packagecloud.io/gpg.key | apt-key add - \
	&& curl -sL https://repos.influxdata.com/influxdb.key | apt-key add - \
	&& source /etc/os-release \
	&& echo "deb https://packagecloud.io/grafana/stable/debian/ jessie main" | tee /etc/apt/sources.list.d/influxdb.list \
	&& echo "deb https://repos.influxdata.com/debian jessie stable" | tee /etc/apt/sources.list.d/influxdb.list \
	&& apt-get update && apt-get install -y \
		influxdb \
		grafana \
	&& systemctl daemon-reload \
	&& systemctl start grafana-server \
	&& systemctl start influxdb \
	&& systemctl enable grafana-server.service \
	&& systemctl enable influxdb.service


COPY ./xap-manager.conf /etc/apache2/sites-available/
RUN a2enmod proxy_http \
    && a2ensite xap-manager.conf \
    && service apache2 stop

COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

WORKDIR ${XAP_HOME_DIR}

EXPOSE 10000-10100 9104 7102 4174 8090 8099

CMD ["/etc/init.d/apache2 start && ./bin/gs-agent.sh"]