#!/bin/bash
cd $(dirname ${BASH_SOURCE[0]})/..
for i in pics future-pics
do
 exiftool -geotag= $i/*.jpg || true
 rm -f $i/*original
done
