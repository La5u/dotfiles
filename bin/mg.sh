#!/bin/bash

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  echo "Usage: $0 <filename> <start time> <duration> [output file]"
  exit 1
fi

filename=$1
echo "FILE: [$filename]"
start_time=$2
duration=$3
output_file=${4:-output.gif}

ffmpeg -ss "$start_time" -i "$filename" -t "$duration" -vf format=yuv420p -f yuv4mpegpipe - | gifski --quality 90 -o "$output_file" -

echo "GIF created successfully: $output_file"

mpv --loop=inf "$output_file"
