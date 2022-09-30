#!/bin/bash

SOURCE=${1:-gar_xml.zip}
TARGET=${2:-_extracted}
REGIONS=${REGIONS:-78}

for ID in "00" ${REGIONS}; do
    if [[ "$ID" -eq "00" ]]; then
        mkdir -p ${TARGET} 2>/dev/null
        unzip -o -j ${SOURCE} '*' -x '*/*' -d ${TARGET}
    else
        mkdir -p ${TARGET}/$ID 2>/dev/null
        unzip -o -j ${SOURCE} $ID'/*' -d ${TARGET}/$ID
    fi
done
