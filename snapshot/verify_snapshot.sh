#!/bin/bash

if [ $# -lt 1 ]; then 
  echo "Usage : $0 [Snapshot file]"
  exit 1
fi

if [ ! -r $1 ]; then 
  echo "$1 Snapshot file is not found" 
  exit 1
fi

T_AMT=0
CNT=0
T_CNT=$(cat $1 | wc -l)
for amt in $(cat $1 | awk -F"," '{print $4}' | sed "s/\"//g");do
  ((CNT++))
  T_AMT=$(echo "scale=5; $T_AMT+$amt" | bc)
  printf "\r  [ ${CNT}/${T_CNT} ] EOS Sum Balance : ${T_AMT}"
done

