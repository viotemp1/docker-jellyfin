#!/bin/bash

#docker build --tag 'comskip_qsv' .

# --no-cache
docker build --progress=plain --tag 'comskip_qsv' --build-arg="JELLYFIN_RELEASE=10.8.13-1" .
