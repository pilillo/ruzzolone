# Ruzzolone

A postgis & pgrouting DB with routes imported from OSM data

## Build example

```
docker build -t ruzzolone .
```

The following build args can be provided (default values provided aside):
* POSTGRES_MAJOR=13
* POSTGIS_MAJOR=3.1
* PGROUTING_VERSION=3.1.3
* INSTALLATION_DIR=/opt/ruzzolone
* OSMPO_VERSION=5.3.6
* MAP_URL=https://download.geofabrik.de/europe/iceland-latest.osm.pbf


## Run Example
```
docker run --rm --name my-pgrouting -p 5432:5432 -e POSTGRES_USER=user -e POSTGRES_PASSWORD=secret ruzzolone:latest
```
