#!/usr/bin/env bash

# set -Eeuxo pipefail

function get_duration {
	return `ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 "$1"`
}

function compare_by_duration {
	get_duration "$1"
	local DURATION1=$?

	get_duration "$2"
	local DURATION2=$?

	if [ ${DURATION1} -eq ${DURATION2} ]
	then
		return 1
	else
		return 0
	fi
}

function compare_by_frames {
	# TODO Compare multiple frames
	# TODO Get frames based on duration
	# TODO Use cache directory
	local WORK_DIR=`mktemp -d`
	echo "[DEBUG] Working dir is ${WORK_DIR}"

	local W_FILE1=${WORK_DIR}/1.jpeg
	local W_FILE2=${WORK_DIR}/2.jpeg
	local W_DIFF=${WORK_DIR}/diff.jpeg

	ffmpeg -i "$1" -ss 00:00:10 -frames:v 1 ${W_FILE1} 1>/dev/null 2>/dev/null
	ffmpeg -i "$2" -ss 00:00:10 -frames:v 1 ${W_FILE2} 1>/dev/null 2>/dev/null

	local DELTA=`compare ${W_FILE1} ${W_FILE2} -format "%[distortion]" ${W_DIFF}`
	rm -rf ${WORK_DIR}

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
	compare_by_duration "$1" "$2"
	_result=$?
	if [ ${_result} -eq 0 ]
	then
		echo "[DEBUG] \"$1\" differ from \"$2\" by duration"
		return 1
	else
		compare_by_frames "$1" "$2"
		_result=$?
		if [ ${_result} -eq 0 ]
		then
			echo "[DEBUG] \"$1\" differ from \"$2\" by frames"
			return 1
		else
			echo "[DEBUG] \"$1\" looks equal to \"$2\""
			return 0
		fi
	fi
}

array=()
find $1 -print0 -type f -exec file -N -i -- {} + | sed -n 's!: video/[^:]*$!!p' >tmpfile
while read p; do
    array+=("$p")
done <tmpfile
rm -f tmpfile

echo "[DEBUG] Found ${#array[@]} video files"

# iterate through array using a counter
for ((i=0; i<${#array[@]}; i++)); do
	for ((j=$i+1; j<${#array[@]}; j++)); do
		echo "[DEBUG] Compare \"${array[$i]}\" with \"${array[$j]}\""

		compare_files "${array[$i]}" "${array[$j]}"
		_result=$?
		if [ ${_result} -eq 1 ]
		then
			echo "\"${array[$i]}\" differ from \"${array[$j]}\""
		else
			echo "\"${array[$i]}\" looks equal to \"${array[$j]}\""
		fi
	done
done
