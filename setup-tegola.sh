#!/bin/bash
set -e

# get the pbf file (returns 1 and exits)
# something like iceland-latest.osm.pbf
PBFILE="$(basename -- $INSTALLATION_DIR/*.pbf)"
# enrich topology with other osm info
## using osm2pgsql
# osm2pgsql --slim -C 18000 --number-processes 8 --host localhost --port 5432 --database $POSTGRES_DB --username $POSTGRES_USER $PBFILE

POSTGIS_CONN_STRING="postgis://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}/${POSTGRES_DB}"

# enable hstore
psql -U $POSTGRES_USER -d $POSTGRES_DB -c "CREATE EXTENSION hstore;"

## using imposm3 - 2 phases
./imposm3/imposm3 import -connection ${POSTGIS_CONN_STRING} -mapping imposm3.json -read ./${PBFILE} -write
./imposm3/imposm3 import -connection ${POSTGIS_CONN_STRING} -mapping imposm3.json -deployproduction
# cleanup
rm -rf ./imposm3
rm ${PBFILE}

# 4. Import OSM Land dataset 
# taken from: https://raw.githubusercontent.com/go-spatial/tegola-osm/master/osm_land.sh
# This script will install the Open Street Maps land polygons (simplified for zooms 0-9 and split for zooms 10-20).
#
# The script assumes the following utilities are installed:
# 	- psql: PostgreSQL client
#	- ogr2ogr: GDAL vector lib
#	- unzip: decompression util
#
# Important
#	- The tegola config file is expecting these layers to be in the same database as the rest of the OSM data imported using imposm3
#	- This script will drop the tables simplified_land_polygons and land_polygons if they exist and then replace them.

# check our connection string before we do any downloading
psql "dbname='postgres' host='$POSTGRES_HOST' port='$POSTGRES_PORT' user='$POSTGRES_USER' password='$POSTGRES_PASSWORD'" -c "\q"

# array of natural earth dataset URLs
dataurls=(
	"https://osmdata.openstreetmap.de/download/land-polygons-split-3857.zip"
)

psql "dbname='$POSTGRES_DB' host='$POSTGRES_HOST' port='$POSTGRES_PORT' user='$POSTGRES_USER' password='$POSTGRES_PASSWORD'" -c "DROP TABLE IF EXISTS land_polygons"

# iterate our dataurls
for i in "${!dataurls[@]}"; do
	url=${dataurls[$i]}

	echo "fetching $url";
	curl $url > $i.zip;
	unzip $i -d $i

	shape_file=$(find $i -type f -name "*.shp")

	echo $shape_file

	# reproject data to webmercator (3857) and insert into our database
	OGR_ENABLE_PARTIAL_REPROJECTION=true ogr2ogr -overwrite -t_srs EPSG:3857 -nlt PROMOTE_TO_MULTI -f PostgreSQL PG:"dbname='$POSTGRES_DB' host='$POSTGRES_HOST' port='$POSTGRES_PORT' user='$POSTGRES_USER' password='$POSTGRES_PASSWORD'" $shape_file

	# clean up
	rm -rf $i/ $i.zip
done

## 5. Install SQL helper functions
# https://github.com/go-spatial/tegola-osm/blob/master/postgis_helpers.sql
psql -U $POSTGRES_USER -d $POSTGRES_DB << EOF
BEGIN;

 -- Inspired by http://stackoverflow.com/questions/16195986/isnumeric-with-postgresql/16206123#16206123
CREATE OR REPLACE FUNCTION as_numeric(text) RETURNS NUMERIC AS $$
DECLARE test NUMERIC;
BEGIN
     test = $1::NUMERIC;
     RETURN test;
EXCEPTION WHEN others THEN
     RETURN -1;
END;
$$ STRICT
LANGUAGE plpgsql IMMUTABLE;

COMMIT;
EOF

## 6. add indexes as in https://raw.githubusercontent.com/go-spatial/tegola-osm/master/postgis_index.sql
psql -U $POSTGRES_USER -d $POSTGRES_DB << EOF
BEGIN;
	CREATE INDEX ON osm_transport_lines_gen0 (type);
	CREATE INDEX ON osm_transport_lines_gen1 (type);
	CREATE INDEX ON osm_transport_lines (type);
	CREATE INDEX ON osm_admin_areas (admin_level);
	CREATE INDEX ON osm_landuse_areas_gen0 (type);
	CREATE INDEX ON osm_water_lines (type);
	CREATE INDEX ON osm_water_lines_gen0 (type);
	CREATE INDEX ON osm_water_lines_gen1 (type);
	CREATE INDEX ON osm_water_areas (type);
	CREATE INDEX ON osm_water_areas_gen0 (type);	
	CREATE INDEX ON osm_water_areas_gen1 (type);
COMMIT;
EOF
