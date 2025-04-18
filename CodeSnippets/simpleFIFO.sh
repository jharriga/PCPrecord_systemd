#!/bin/bash
# bash-a-simple-fifo example code

#--- setup
FIFO="/tmp/fifo.tmp"
rm -f "$FIFO"
mkfifo "$FIFO"

#--- sending data in background
for (( i = 0; i < 10; i++ )); do 
  echo $i 
  sleep 1
done >"$FIFO" &

#--- receiving data
echo "start"
while read line; do
  echo "> $line"
done < "$FIFO"
echo "stop"

#--- clean
rm -f "$FIFO"

