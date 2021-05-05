#!/bin/bash

# start postgres
docker-entrypoint.sh postgres &

# use db var ifset or username otherwise
POSTGRES_DB=${POSTGRES_DB:-$POSTGRES_USER}

# query list until available
function query {
  $(psql -U $POSTGRES_USER -d $POSTGRES_DB -q -c "\dt" > /dev/null 2>&1) || {
    echo "DB not ready, waiting..."
    sleep 1;
    query
  }
}

query

# enable postgis and pgrouting
psql -U $POSTGRES_USER -d $POSTGRES_DB << EOF
CREATE EXTENSION postgis;
CREATE EXTENSION pgrouting;
SELECT pgr_version();
EOF

# import ways
psql -U $POSTGRES_USER -d $POSTGRES_DB -q -f osm_2po_4pgr.sql

# generate vertices table
psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT pgr_createVerticesTable('osm_2po_4pgr', 'geom_way', 'source', 'target', 'true');"

# enrich topology with other osm info
#osm2pgsql --create --database $POSTGRES_DB --username $POSTGRES_USER *.pbf

wait
echo "Exiting..."
