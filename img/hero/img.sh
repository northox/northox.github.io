#!/usr/bin/env bash
for i in `ls`; do convert $i -resize 2000x2000 -strip -interlace Plane -gaussian-blur 0.05 -quality 90% $i; done
