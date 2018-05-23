#!/bin/bash
conf_file=node_setup.conf
[ -f $conf_file ] && . $conf_file
if [ -z $DATA_DIR ]
then
  echo "  >> Not found $conf_file. please set to environment file."
  exit 0;
fi

init_list () {
  BP_LIST=()
  PORT_LIST=()
  HOST_LIST=()
  for((x=1;x<=${#PDNAME[@]};x++));
  do
    eval $( awk -F"|" '{print "PNAME=\""$1"\" HOSTNAME="$2" HTTP_PORT="$3" P2P_PORT="$4" SSL_PORT="$5" ORG=\""$6"\" LOCALE=\""$7"\""}' <<< ${PDNAME[$x]} )
    BP_LIST+=("$PNAME")
    PORT_LIST+=("$HTTP_PORT")
    HOST_LIST+=("$HOSTNAME")
  done
}

print_bp() {
  echo "################################"
  for((x=0;x<${#BP_LIST[@]};x++));
  do
    printf "%3s : %12s (Port:%5s)\n" "$x" "${BP_LIST[$x]}" "${PORT_LIST[$x]}"
  done
  echo "################################"
  read -p " SELECT Node number : : " s_val
  echo 
  echo "=============================================="
  echo "   If you want to exit then Press CTRL + C  "
  echo "   - HOST : ${HOST_LIST[$s_val]}"
  echo "   - PORT : ${PORT_LIST[$s_val]}"
  echo "=============================================="

}

init_list
print_bp
while true; do
  read -p "Neo EOS> " -a CMD
  $EOS_BIN/cleos/cleos -u http://${HOST_LIST[$s_val]}:${PORT_LIST[$s_val]} --wallet-url http://${WALLET_HOST}:${WALLET_PORT} ${CMD[@]}
done
