#!/bin/bash
conf_file=node_setup.conf
[ -f $conf_file ] && . $conf_file
if [ -z $DATA_DIR ]
then
  echo "  >> Not found $conf_file. please set to environment file."
  exit 0;
fi

if [ $# -lt 1 ]
then
  echo "Usage : $0 [start|stop|restart] {NodeName}"
exit 1
fi


if [ ! -z $2 ]
then
  if [ -x $DATA_DIR/td_node_$2/run.sh ]
  then 
     $DATA_DIR/td_node_$2/run.sh $1
  else
     echo "  > NodeName [$2] is not match. check to $DATA_DIR/td_node_$2"
  fi
else
  for((x=1;x<=${#PDNAME[$x]};x++));do
    PNAME=$( awk -F"|" '{print $1}' <<< ${PDNAME[$x]})
    if [ -x $DATA_DIR/td_node_${PNAME}/run.sh ]
    then 
        $DATA_DIR/td_node_${PNAME}/run.sh $1 
    else 
        echo "  > we're not found to $DATA_DIR/td_node_${PNAME}/run.sh script."
    fi
  done
fi
