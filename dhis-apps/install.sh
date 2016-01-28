#!/bin/bash

CWD=$(pwd)
DIRS=("csd-loader" "macm-reporter")
for DIR in ${DIRS[@]}
do
    echo "Packaging $DIR"
    cd $CWD/$DIR  
    zip -r $CWD/$DIR.zip *
    echo "Uploading $DIR"
    curl -k -X POST -u admin:district -F file=@$CWD/$DIR.zip https://localhost/dhis/api/apps
done

