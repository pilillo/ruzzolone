
ARG POSTGRES_MAJOR=13
ARG POSTGIS_MAJOR=3.1
ARG PGROUTING_VERSION=3.1.3
ARG INSTALLATION_DIR=/opt/ruzzolone

ARG OSMPO_VERSION=5.3.6
ARG MAP_URL=https://download.geofabrik.de/europe/iceland-latest.osm.pbf

FROM openjdk:8-jre-alpine as javabase

ARG MAP_URL
ARG OSMPO_VERSION
ARG INSTALLATION_DIR

WORKDIR $INSTALLATION_DIR

ADD http://osm2po.de/releases/osm2po-${OSMPO_VERSION}.zip $INSTALLATION_DIR
RUN apk add --no-cache && \
    unzip osm2po-${OSMPO_VERSION} && \
    rm *.zip

# download map if a url is provided, or expect one available locally otherwise
ADD $MAP_URL $INSTALLATION_DIR
#RUN [[ ! -z "${MAP_URL}" ]] && wget ${MAP_URL} -P ${INSTALLATION_DIR} || echo "Empty MAP_URL: skipping map download!"

COPY osm2po.config $INSTALLATION_DIR
RUN java -Xmx1024m -jar osm2po-core-${OSMPO_VERSION}-signed.jar cmd=c *.pbf

FROM pgrouting/pgrouting:${POSTGRES_MAJOR}-${POSTGIS_MAJOR}-${PGROUTING_VERSION} as pgbase

ARG INSTALLATION_DIR
ENV INSTALLATION_DIR=$INSTALLATION_DIR
WORKDIR $INSTALLATION_DIR
COPY --from=javabase $INSTALLATION_DIR/osm/osm_2po_4pgr.sql .
COPY --from=javabase $INSTALLATION_DIR/*.pbf .

ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--"]

ENV POSTGRES_HOST=localhost
ENV POSTGRES_PORT=5432

COPY entrypoint.sh /usr/local/bin
CMD ["entrypoint.sh"]
