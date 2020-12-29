#!/usr/bin/env bash

# set -Eeuxo pipefail

FILE1=$1
FILE2=$2

WORK_DIR=`mktemp -d`
echo "[DEBUG] Working dir is ${WORK_DIR}"

W_FILE1=${WORK_DIR}/1.jpeg
W_FILE2=${WORK_DIR}/2.jpeg
W_DIFF=${WORK_DIR}/diff.jpeg

ffmpeg -i ${FILE1} -ss 00:00:10 -frames:v 1 ${W_FILE1} 1>/dev/null 2>/dev/null
ffmpeg -i ${FILE2} -ss 00:00:10 -frames:v 1 ${W_FILE2} 1>/dev/null 2>/dev/null

DELTA=`compare ${W_FILE1} ${W_FILE2} -format "%[distortion]" ${W_DIFF}`

echo "[DEBUG] Equality rate is: ${DELTA}"

_output=`echo "${DELTA} > 0.9" | bc`
if [ ${_output} -eq "1" ];
then
	echo "${FILE1} looks equal to ${FILE2}"
else
	echo "${FILE1} differ from ${FILE2}"
fi

