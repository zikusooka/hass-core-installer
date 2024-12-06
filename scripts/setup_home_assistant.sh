#!/bin/bash
clear



JAMBULA_DATA_DIR=/jambula
JAMBULA_STORAGE_DIR=${JAMBULA_DATA_DIR}/storage


# Create media directories if non-existent
for MEDIA_DIR in \
	Music \
	TV_Recordings \
	TV_Shows Movies \
	Podcasts \
	Pictures 
do
	[[ -d "${JAMBULA_STORAGE_DIR}/$MEDIA_DIR" ]] || mkdir -p "${JAMBULA_STORAGE_DIR}/$MEDIA_DIR"
done
