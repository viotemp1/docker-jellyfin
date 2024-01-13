#!/bin/bash

#docker run -d \
#	--name=comskip_qsv \
#	--restart unless-stopped \
#	-e PUID=$(id -u) \
#	-e PGID=$(id -g) \
#	-e TZ=Europe/Bucharest \
#	-p 8096:8096 \
#	-v /home/viorelublea/jellyfin/config:/config \
#       -v /home/viorelublea/jellyfin/cache:/cache \
#	-v /home/viorelublea/plex/Library:/data \
#	--device=/dev/dri:/dev/dri \
#comskip_qsv

docker run --rm -it --device=/dev/dri comskip_qsv /bin/bash
