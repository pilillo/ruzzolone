# Ruzzolone - Makefile
export POSTGRES_MAJOR=13
export POSTGIS_MAJOR=3.1
export PGROUTING_VERSION=3.1.3
export INSTALLATION_DIR=/opt/ruzzolone
export OSMPO_VERSION=5.3.6
# either local or url-based map
export MAP_URL=./iceland-latest.osm.pbf
#export MAP_URL=https://download.geofabrik.de/europe/iceland-latest.osm.pbf

export POSTGRES_USER=tegola
export POSTGRES_PASSWORD=secret

build-ruzzolone:
	docker build \
	--build-arg POSTGRES_MAJOR --build-arg POSTGIS_MAJOR --build-arg PGROUTING_VERSION --build-arg OSMPO_VERSION \
	--build-arg MAP_URL -t ruzzolone .

run-ruzzolone: build-ruzzolone
	docker run --rm --name ruzzolone \
	-p 5432:5432 \
	--env POSTGRES_USER --env POSTGRES_PASSWORD \
	ruzzolone:latest

build-ruzzolone-raster: ruzzolone
	docker build -t ruzzolone-raster -f Dockerfile.raster .

run-ruzzolone-raster: build-ruzzolone-raster
	docker run --rm --name ruzzolone-raster \
	-p 5432:5432 -e POSTGRES_USER -e POSTGRES_PASSWORD \
	-e SRID=3035 -e TILE_SIZE=1000x1000 -e SCHEMA_TABLE=public.eu_dem \
	--mount type=bind,source="$(pwd)"/data,target=/data \
	ruzzolone-raster:latest

build-tegola: build-ruzzolone
	docker build -t ruzzolone-tegola -f Dockerfile.tegola .

run-tegola: build-tegola
	docker run --rm --name ruzzolone-tegola \
	-p 5432:5432 -e POSTGRES_USER -e POSTGRES_PASSWORD \
	ruzzolone-tegola:latest