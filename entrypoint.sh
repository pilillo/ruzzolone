#!/bin/bash
set -e

# start postgres
docker-entrypoint.sh postgres &

# use db var ifset or username otherwise
export POSTGRES_DB=${POSTGRES_DB:-$POSTGRES_USER}

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
CREATE EXTENSION postgis_raster;
CREATE EXTENSION pgrouting;
SELECT pgr_version();
EOF

# import ways
psql -U $POSTGRES_USER -d $POSTGRES_DB -q -f osm_2po_4pgr.sql

# generate vertices table
psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT pgr_createVerticesTable('osm_2po_4pgr', 'geom_way', 'source', 'target', 'true');"

# get the pbf file (returns 1 and exits)
# something like iceland-latest.osm.pbf
export PBFILE="$(basename -- $INSTALLATION_DIR/*.pbf)"
# enrich topology with other osm info
## using osm2pgsql
# osm2pgsql --slim -C 18000 --number-processes 8 --host localhost --port 5432 --database $POSTGRES_DB --username $POSTGRES_USER $PBFILE

if [ ! -z "$1" ]; then
  echo "Loading setup file at $1"
  source ${1}
fi

wait
echo "Exiting..."
