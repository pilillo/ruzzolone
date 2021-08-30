#!/bin/bash
set -e

# add dem data if any is available
command -v raster2pgsql >/dev/null 2>&1 && [ -d "/data" ] && {
  readarray -d '' TIF_FILES < <(find /data -type f \( -iname \*.TIF -o -iname \*.tif \))
  # load all available tif files in any subfolder of /data
  for TIF_FILE in "${TIF_FILES[@]}"
  do
    raster2pgsql -c -C -s ${SRID} -M -t ${TILE_SIZE} -I ${TIF_FILE} ${SCHEMA_TABLE} | psql -U $POSTGRES_USER -d $POSTGRES_DB
  done
}