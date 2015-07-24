#!/bin/bash
docker run -t -v $(pwd)/../:/code ruby-2.2.2 /bin/bash -c /code/docker-packager/packager.sh
