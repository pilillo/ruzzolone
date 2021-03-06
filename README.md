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

after building this as a base, you can build its raster variant that re-installs postgis to get raster support and CLI tools:
```
docker build -t ruzzolone-raster -f Dockerfile.raster .
```

## Run Example
To start the base pgrouting image:
```
docker run --rm --name my-pgrouting -p 5432:5432 -e POSTGRES_USER=user -e POSTGRES_PASSWORD=secret ruzzolone:latest
```

or the raster variant (which imports DEM data provided as tif file in the data folder):
```
docker run --rm --name my-pgrouting \
-p 5432:5432 -e POSTGRES_USER=user -e POSTGRES_PASSWORD=secret \
-e SRID=3035 -e TILE_SIZE=1000x1000 -e SCHEMA_TABLE=public.eu_dem \
--mount type=bind,source="$(pwd)"/data,target=/data \
ruzzolone-raster:latest
```

You can also use the Makefile to build and run the image, for instance:
```
make run-tegola
```

will be the same as running `make build-ruzzolone` followed by `make build-tegola` and a docker run on the resulting tegola image.

Unless modified, the build process will download, convert and load the route map of Iceland.

To run an example query you can use any PostgreSQL client, such as psql. 

For instance:

```
select r.seq, r.node, w.osm_name as street, r.cost::numeric(10,4), (sum(ST_Length(w.geom_way::geography)) over(order by r.seq))::numeric(10,2) as dist_m
from pgr_dijkstra(
	'select id, source, target, cost, reverse_cost from osm_2po_4pgr',
	(select id from osm_2po_4pgr_vertices_pgr order by the_geom <-> ST_SetSRID(ST_Point(-21.896194, 64.131259), 4326) limit 1),
	(select id from osm_2po_4pgr_vertices_pgr order by the_geom <-> ST_SetSRID(ST_Point(-21.894693, 64.128251), 4326) limit 1),
	true
) as r
left join osm_2po_4pgr as w on r.edge = w.id;
```
where locations are expressed as `ST_Point(longitude, latitude)` (also respectively named x and y) pairs.

which will return:

```
| seq   | node  | street       | cost   | dist_m |
|-------|-------|--------------|--------|--------|
| 1     | 15541 | "Kringlan"   | 0.0021 | 105.96 |
| 2     | 14187 | "Kringlan"   | 0.0006 | 136.71 |
| 3     | 14221 | "Kringlan"   | 0.0010 | 187.09 |
| 4     | 14183 | "Kringlan"   | 0.0004 | 208.99 |
| 5     | 14202 | "Kringlan"   | 0.0003 | 225.85 |
| 6     | 8202  | "Kringlan"   | 0.0006 | 257.12 |
| 7     | 15078 | "Kringlan"   | 0.0006 | 285.48 |
| 8     | 44099 | "Kringlan"   | 0.0001 | 290.65 |
| 9     | 949   | "Kringlan"   | 0.0003 | 307.10 |
| 10    | 44104 | "Listabraut" | 0.0011 | 361.32 |
| 11    | 59469 | "Listabraut" | 0.0011 | 415.17 |
| 12    | 5798  | "Listabraut" | 0.0006 | 447.32 |
| 13    | 19378 | "Listabraut" | 0.0005 | 470.70 |
| 14    | 44107 | "Listabraut" | 0.0001 | 476.48 |
| 15    | 16558 | "Listabraut" | 0.0001 | 480.31 |
| 16    | 16555 | "Kringlan"   | 0.0002 | 488.81 |
| 17    | 44108 | "Listabraut" | 0.0002 | 498.14 |
| 18    | 44109 |              | 0.0000 | 498.14 |
```

## Additional references

### PGRouting
* https://pgrouting.org/documentation.html
* https://live.osgeo.org/en/quickstart/pgrouting_quickstart.html
* https://workshop.pgrouting.org/2.6/en/index.html
* [Download OSM Data](http://download.geofabrik.de/)

### DEM
* https://opendem.info/link_dem.html
* https://www.ngdc.noaa.gov/mgg/topo/gltiles.html
* https://www.opentopodata.org/datasets/eudem/
* https://land.copernicus.eu/imagery-in-situ/eu-dem/eu-dem-v1.1
* https://www.opentopodata.org/datasets/aster30m_urls.txt
* http://themagiscian.com/2016/11/28/dem-slope-calculations-bicycle-routing-postgis/
* https://github.com/ajnisbet/opentopodata
* https://www.opentopodata.org/server/
* https://gis-ops.com/postgrest-postgis-api-tutorial-serve-digital-elevation-models/

### OSM Tile Serving with Tegola
* https://github.com/go-spatial/tegola-osm/