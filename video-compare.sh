#!/usr/bin/env bash

# set -Eeuxo pipefail

function get_duration {
	return `ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 $1`
}

function compare_by_duration {
	get_duration $1
	local DURATION1=$?

	get_duration $2
	local DURATION2=$?

	if [ ${DURATION1} -eq ${DURATION2} ]
	then
		return 1
	else
		return 0
	fi
}

function compare_by_frames {
	local WORK_DIR=`mktemp -d`
	echo "[DEBUG] Working dir is ${WORK_DIR}"

	local W_FILE1=${WORK_DIR}/1.jpeg
	local W_FILE2=${WORK_DIR}/2.jpeg
	local W_DIFF=${WORK_DIR}/diff.jpeg

	ffmpeg -i ${FILE1} -ss 00:00:10 -frames:v 1 ${W_FILE1} 1>/dev/null 2>/dev/null
	ffmpeg -i ${FILE2} -ss 00:00:10 -frames:v 1 ${W_FILE2} 1>/dev/null 2>/dev/null

	local DELTA=`compare ${W_FILE1} ${W_FILE2} -format "%[distortion]" ${W_DIFF}`

	echo "[DEBUG] Equality rate is: ${DELTA}"

	local _output=`echo "${DELTA} > 0.9" | bc`
	if [ ${_output} -eq "1" ];
	then
		return 1
	else
		return 0
	fi
}

function compare_files {
	compare_by_duration ${FILE1} ${FILE2}
	_result=$?
	if [ ${_result} -eq 0 ]
	then
		echo "[DEBUG] ${FILE1} differ from ${FILE2} by duration"
		return 1
	else
		compare_by_frames ${FILE1} ${FILE2}
		_result=$?
		if [ ${_result} -eq 0 ]
		then
			echo "[DEBUG] ${FILE1} differ from ${FILE2} by frames"
			return 1
		else
			echo "[DEBUG] ${FILE1} looks equal to ${FILE2}"
			return 0
		fi
	fi
}

FILE1=$1
FILE2=$2

compare_files ${FILE1} ${FILE2}
_result=$?
if [ ${_result} -eq 1 ]
then
	echo "${FILE1} differ from ${FILE2}"
	exit 1
else
	echo "${FILE1} looks equal to ${FILE2}"
	exit 0
fi
