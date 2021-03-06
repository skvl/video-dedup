#!/usr/bin/env bash

# set -x

files=()
durations=()

function get_duration {
	ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 "$1" >tmpfile
	local duration=`cat tmpfile`
	durations+=($duration)
	rm -f tmpfile
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

function compare_by_duration_cached {
	local DURATION1=${durations[$1]}
	local DURATION2=${durations[$2]}

	if [ ${DURATION1} -eq ${DURATION2} ]
	then
		return 1
	else
		return 0
	fi
}

function compare_by_frames {
	# TODO Compare multiple frames
	# TODO Use cache directory
	local WORK_DIR=`mktemp -d`
	echo "[DEBUG] Working dir is ${WORK_DIR}"

	local W_FILE1=${WORK_DIR}/1.jpeg
	local W_FILE2=${WORK_DIR}/2.jpeg
	local W_DIFF=${WORK_DIR}/diff.jpeg

	let "timestamp1 = ${durations[$1]} / 2"
	echo "[DEBUG] Timestamp ${timestamp1}"
	ffmpeg -i "${files[$1]}" -vf "select=eq(n\,${timestamp1})" -q:v 3 ${W_FILE1} 1>/dev/null 2>/dev/null
	ffmpeg -i "${files[$2]}" -vf "select=eq(n\,${timestamp1})" -q:v 3 ${W_FILE2} 1>/dev/null 2>/dev/null

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
	compare_by_duration_cached $1 $2
	_result=$?
	if [ ${_result} -eq 0 ]
	then
		echo "[DEBUG] \"$1\" differ from \"$2\" by duration"
		return 1
	else
		compare_by_frames $1 $2
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

find $1 -type f -exec file -N -i -- {} + | sed -n 's!: video/[^:]*$!!p' >tmpfile
while read p; do
    files+=("$p")
	echo "[DEBUG] Found video file \"$p\""
done <tmpfile
rm -f tmpfile

echo "[DEBUG] Found ${#files[@]} video files"

for ((i=0; i<${#files[@]}; i++)); do
	get_duration "${files[$i]}"
	echo "[DEBUG] [$i] Get duration of \"${files[$i]}\": ${durations[$i]}"
done

# iterate through files using a counter
for ((i=0; i<${#files[@]}; i++)); do
	for ((j=$i+1; j<${#files[@]}; j++)); do
		echo "[DEBUG] Compare \"${files[$i]}\" with \"${files[$j]}\""

		# TODO Refactor arguments
		compare_files $i $j
		_result=$?
		if [ ${_result} -eq 1 ]
		then
			echo "\"${files[$i]}\" differ from \"${files[$j]}\""
		else
			echo "\"${files[$i]}\" looks equal to \"${files[$j]}\""
		fi
	done
done
