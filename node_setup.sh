#!/bin/bash
conf_file=node_setup.conf
[ -f $conf_file ] && . $conf_file
if [ -z $DATA_DIR ]
then
  echo "  >> Not found $conf_file in $(pwd) directory. please set to node_setup.conf file."
  exit 0;
fi

# Define cleos command options
CLE="$EOS_BIN/cleos/cleos -u http://$BOOT_HOST:$BOOT_HTTP --wallet-url http://${WALLET_HOST}:${WALLET_PORT}"

# Define ECHO function
echo_f ()
{
  message=${1:-"[ Failed ]"}
  printf "\033[1;31m%s\033[0m\n" "$message"
}
echo_s ()
{
  message=${1:-"[ Success ]"}
  printf "\033[1;32m%s\033[0m\n" "$message"
}
echo_k ()
{
  message=${1:-"[ Failed ]"}
  printf "\033[1;33m%s\033[0m\n" "$message"
  exit 1;
}
echo_fx ()
{
  message=${1:-"[ Failed ]"}
  printf "\033[1;31m%s\033[0m\n" "$message"
  exit 1;
}
echo_ret () { 
  echo -ne "$1"
  [ $2 -eq 0 ] && echo_s || echo_f
}

echo_head () { 
echo -e '
################################################################################
#                                                                              #
#        EOSeoul Testnet builder for developers                                #
#        made by Sungmin.Ma @2018.04                                           #
#                                                                              #
#        visit to http://eoseoul.io                                            #
#        Contact to Telegram (https://t.me/eoseoul_testnet)                    #
#                                                                              #
################################################################################
'
}

echo_end () {
if [ $LOAD_SNAPSHOT -eq 1 ]; then
echo -e "
################################################################################
#                                                                              #
#   \033[1;33mAbout Snapshot migration\033[0m                                                   #
#                                                                              #
#   We have migrated accounts based on Snapshot files.                         #
#   For information on migrated accounts, please refer to the                  #
#   file \"boot / migration_YYYYMMDD.csv\".                                      #
#                                                                              #
################################################################################"
fi
echo "
################################################################################
#                                                                              #
#    Now, we complete to installation and running node.                        #
#                                                                              #
#    nodeos testnet Installation is complete.                                  #
#    Both the boot node and the configured BP Node are running.                #
#    Run the regproducer.sh script in the BP Node directory to register        #
#    as Producer (Election node).                                              #
#                                                                              #
#    Use the command \"tail -f td_node_BPNAME/ stderr.txt\" to see if the        #
#    BP Node works as a Producer.                                              #
#                                                                              #
#    If the BP Node is normally producing, stop the boot node.                 #
#    To stop the boot node, use the command \"./boot/run.sh stop\".              #
#                                                                              #
#    If you have any questions, please contact us via Telegram.                #
#                                                                              #
################################################################################
"
}

function ProgressBar {
    let _progress=(${1}*100/${2}*100)/100
    let _done=(${_progress}*4)/10
    let _left=40-$_done
    _fill=$(printf "%${_done}s")
    _empty=$(printf "%${_left}s")

    printf "\r   Progress : [${_fill// /#}${_empty// /-}] ${_progress}%% (${1}/${2})"
}
#"

check_os () {
  echo -ne "  -- Check OS : "
  OS_NAME=$(cat /etc/os-release | grep "^NAME" | awk -F"=" '{print $2}' | sed "s/\"//g")
  if [ $OS_NAME != "Ubuntu" ]
  then
    echo_f 
    echo "  -- This scripts support only ubuntu!"
    exit 1
  else
    echo_s
  fi
}

source_check () { 
  echo "  -- Check EOS Source file"
  rp_chk=$(git ls-remote $GIT_REPO |  egrep "(heads|tags)/$EOS_RELEASE" | wc -l)
  if [ $rp_chk -eq 0 ] 
  then
    echo "  -- Git Repo or Release is not available. check EOS_RELEASE in $conf_file"
    exit 1
  fi

  if [ ! -d $SRC_DIR ]; then
    git clone http://github.com/eosio/eos $SRC_DIR --recursive
    cd $SRC_DIR; 
    git checkout $EOS_RELEASE; 
    git submodule update --recursive; 
    #Set CORE Token Symbol
    CUR_SYM=${CUR_SYM:-"EOS"}
    if [ $(grep "CORE_SYMBOL_NAME" $SRC_DIR/CMakeLists.txt | grep "set" | grep "$CUR_SYM" | wc -l) -eq 0 ]; then
      echo "  -- Patch CORE Symbol - $CUR_SYM"
      patch -p0 < $DATA_DIR/SymbolPatch.patch
      sed -i "s+__SYMBOL__+$CUR_SYM+g" $SRC_DIR/CMakeLists.txt
    fi
    ./eosio_build.sh
    cd -
  else
    cd $SRC_DIR;
    if [ $(git branch | grep $EOS_RELEASE | wc -l) -eq 0 ]; then 
      git checkout master; git pull; 
      git checkout $EOS_RELEASE; 
      git submodule update --recursive; 
      #Set CORE Token Symbol
      CUR_SYM=${CUR_SYM:-"EOS"}
      if [ $(grep "CORE_SYMBOL_NAME" $SRC_DIR/CMakeLists.txt | grep "set" | grep "$CUR_SYM" | wc -l) -eq 0 ]; then
        echo "  -- Patch CORE Symbol - $CUR_SYM"
        patch -p0 < $DATA_DIR/SymbolPatch.patch
        sed -i "s+__SYMBOL__+$CUR_SYM+g" $SRC_DIR/CMakeLists.txt
      fi
      ./eosio_build.sh
    fi
    cd -
  fi
}

make_dir () {
  echo -ne "  -- Make dir - $1 : "
  if [ ! -d $1 ]
  then 
    mkdir $1
    [ $? -eq 0 ] && echo_s 
  else
    echo "[ Skip ]"
  fi
}



init_bp_node () {
echo "  -- Initialize BP node"
[ ! -d $KEY_DIR ] && make_dir $KEY_DIR
for((x=1;x<=${#PDNAME[@]};x++));
do 
  # Parsing bp node configs
  eval $( awk -F"|" '{print "PNAME=\""$1"\" HOSTNAME="$2" HTTP_PORT="$3" P2P_PORT="$4" SSL_PORT="$5" ORG=\""$6"\" LOCALE=\""$7"\"SiteUrl="$8" IsBP="$9}' <<< ${PDNAME[$x]} )
  if [ $(echo $PNAME | wc -c) -ne 13 ] 
  then 
    echo "The EOS account must be 12 characters."
    exit 1
  fi
  # Check Running Service or BP Directory Exists
  echo -ne "  -- Setup ${PNAME} node : "
  if [ $(node_svc_check "${HOSTNAME}:${HTTP_PORT}") -eq 1 ]
  then
    echo "[ SKIP ]"
    echo "  -- $PNAME node is already running."
    echo "  -- $PNAME HOST : $HOSTNAME / HTTP PORT : $HTTP_PORT"
    continue;
  elif [ -d $DATA_DIR/td_node_${PNAME} ]
  then
    # Check Already set BP config
    echo "[ SKIP ]"
    echo "  -- $PNAME node directory is exists. But it's not working"
    echo "   --- If you want to run, execute this : ./td_node_${PNAME}/run.sh start"
    continue;
  else
    echo_s
    # Create new BP config
    make_dir $DATA_DIR/td_node_$PNAME
    # Create BP key
    $CLE create key > $KEY_DIR/$PNAME.bpkey
    PUB_KEY=$(cat $KEY_DIR/$PNAME.bpkey | grep Public | awk '{print $3}')
    PRIV_KEY=$(cat $KEY_DIR/$PNAME.bpkey | grep Private | awk '{print $3}')
    # Set config.ini for BP node
    sed -e "s/__PUBKEY__/$PUB_KEY/g" \
        -e "s/__PRIVKEY__/$PRIV_KEY/g" \
        -e "s/__HTTPPORT__/${HTTP_PORT}/g" \
        -e "s/__HOSTNAME__/${HOSTNAME}/g" \
        -e "s/__P2PPORT__/${P2P_PORT}/g" \
        -e "s/__NODENAME__/${TESTNET_NAME}-${PNAME}/g" \
        -e "s/#__BOOT_PEER__/p2p-peer-address=${BOOT_HOST}:${BOOT_P2P}/g" \
        -e "s/__PDNAME__/${PNAME}/g" < $DATA_DIR/template/config.ini > $DATA_DIR/td_node_$PNAME/config.ini
    # Set run.sh for BP node
    sed -e "s+__DATA__+$DATA_DIR/td_node_$PNAME+g" \
        -e "s+__BIN__+$EOS_BIN/nodeos/nodeos+g" \
        -e "s/__PROG__/nodeos/g"  < $DATA_DIR/template/run.sh > $DATA_DIR/td_node_$PNAME/run.sh
    chmod 0755 $DATA_DIR/td_node_$PNAME/run.sh
    # Copy Default genesis.json to BP node dir
    cp -a $DATA_DIR/template/genesis.json  $DATA_DIR/td_node_$PNAME/genesis.json
    if [ $IsBP == "true" ]; then
      # DEFINE PEER Informations
      [ -z $PPL ] && PPL="p2p-peer-address=${HOSTNAME}:${P2P_PORT}" || PPL="$PPL\np2p-peer-address=${HOSTNAME}:${P2P_PORT}"
    fi
    # Create EOS BP Account on EOS Blockchain
    echo -ne "  -- Create account - $PNAME : "
    $CLE system newaccount --stake-net "10000.0000 ${CUR_SYM}" --stake-cpu "10000.0000 ${CUR_SYM}" eosio $PNAME $PUB_KEY $PUB_KEY >> $DATA_DIR/td_node_$PNAME/stdout.txt 2>&1
    [ $? -eq 0 ] && echo_s || echo_f
    
    echo -ne "  -- Create Wallet : "
    $CLE wallet create -n $PNAME > $KEY_DIR/$PNAME.wpk
    [ $? -eq 0 ] && echo_s || echo_f

    echo -ne "  -- Wallet Import key "
    $CLE wallet import -n $PNAME $PRIV_KEY >> $DATA_DIR/td_node_$PNAME/stdout.txt 2>&1
    [ $? -eq 0 ] && echo_s || echo_f

    echo -ne "  -- Initailize Coin setting (100000 $CUR_SYM) : "
    $CLE push action eosio.token transfer '["eosio","'$PNAME'","100000.0000 '${CUR_SYM}'","Init Coin"]' -p eosio  >> $DATA_DIR/td_node_$PNAME/stdout.txt 2>&1
    [ $? -eq 0 ] && echo_s || echo_f

    echo -ne "  -- Default Ram Staking (10000 $CUR_SYM) : "
    $CLE system buyram eosio $PNAME "10000.0000 $CUR_SYM" -p eosio >> $DATA_DIR/td_node_$PNAME/stdout.txt 2>&1
    [ $? -eq 0 ] && echo_s || echo_f

    # make cleos.sh
    echo '#!/bin/bash
	'$EOS_BIN'/cleos/cleos -u http://'$HOSTNAME':'$HTTP_PORT' --wallet-url=http://'${WALLET_HOST}':'${WALLET_PORT}' "$@"' > $DATA_DIR/td_node_$PNAME/cleos.sh
    chmod +x $DATA_DIR/td_node_$PNAME/cleos.sh

    # make producer script 
    echo -ne "  -- Make Producer Script [$PNAME]: "
    echo -e '#!/bin/bash 
	_CLE="'$EOS_BIN'/cleos/cleos -u http://'$HOSTNAME':'$HTTP_PORT' --wallet-url=http://'${WALLET_HOST}':'${WALLET_PORT}'"
	$_CLE system regproducer '$PNAME' '$PUB_KEY' "http://eoseoul.io" 900
	sleep 0.5' > $DATA_DIR/td_node_$PNAME/regproducer.sh
    if [ $x -eq 1 ]; then
      # First node nead to 15% coin stake for law #1   
      $CLE push action eosio.token transfer '["eosio","'$PNAME'","200000000.0000 '$CUR_SYM'","Transfer for law-1"]' -p eosio >> $DATA_DIR/td_node_$PNAME/stdout.txt 2>&1
      echo '$_CLE system delegatebw '$PNAME' '$PNAME' "100000000.0000 '$CUR_SYM'" "100000000.0000 '$CUR_SYM'" --transfer -p '$PNAME'' >> $DATA_DIR/td_node_$PNAME/regproducer.sh
    else 
      echo '$_CLE system delegatebw '$PNAME' '$PNAME' "10000.0000 '$CUR_SYM'" "10000.0000 '$CUR_SYM'" --transfer -p '$PNAME'' >> $DATA_DIR/td_node_$PNAME/regproducer.sh
    fi
    echo '	sleep 0.5
	$_CLE system voteproducer prods '$PNAME' '$PNAME'' >> $DATA_DIR/td_node_$PNAME/regproducer.sh
    chmod u+x $DATA_DIR/td_node_$PNAME/regproducer.sh
  fi
done

# Set P2P Peer List on config.ini
for((x=1;x<=${#PDNAME[@]};x++));
do
  PNAME=$( awk -F"|" '{print $1}' <<< ${PDNAME[$x]})
  perl -p  -i -e "s/#__P2P_PEER_LIST__/$PPL/g" $DATA_DIR/td_node_$PNAME/config.ini
done

}

bp_action() {
  $CLE push action eosio setprods "$(cat $BP_PROD)" -p eosio  >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret  "  -- Set Producers : " $?
}

node_control() {
  # function : node_control [start|stop|restart] {BPName}
  if [ ! -z $2 ]
  then 
    echo "  -- $2 BP NODE - $1"
    if [ -x $DATA_DIR/td_node_${2}/run.sh ]
    then
        $DATA_DIR/td_node_${2}/run.sh $1
    else
        echo "  --> we're not found to $DATA_DIR/td_node_${2}/run.sh script."
    fi
  else
    for((x=1;x<=${#PDNAME[@]};x++));do
      PNAME=$( awk -F"|" '{print $1}' <<< ${PDNAME[$x]})
      echo "  -- $PNAME BP NODE $1"
      if [ -x $DATA_DIR/td_node_${PNAME}/run.sh ]
      then
        if [ $(node_svc_check "${HOSTNAME}:${HTTP_PORT}") -eq 1 ]
        then
          echo "  -- $PNAME node is already running."
          continue;
        else
          $DATA_DIR/td_node_${PNAME}/run.sh start
        fi
      else
        echo "  --> we're not found to $DATA_DIR/td_node_${PNAME}/run.sh script."
      fi
    done
  fi
}

clean_all () {
  # Stop all Node
  echo " -- stop all BP nodes"
  $DATA_DIR/node_ctrl.sh stop
  # Stop Boot Node
  if [ -f $DATA_DIR/boot/nodeos.pid ]
  then
    echo " -- stop boot node"
    $DATA_DIR/boot/run.sh stop
  fi
  if [ -f $WALLET_DIR/keosd.pid ]
  then
    echo " -- stop keosd(wallet) node"
    $WALLET_DIR/run.sh stop
  fi
  echo " -- Remove all node data"
  # Clear node data
  rm -rf $DATA_DIR/boot $DATA_DIR/td_node_*  $DATA_DIR/BP_KEY $DATA_DIR/bpnode.db $DATA_DIR/monitor_config.js $WALLET_DIR $DATA_DIR/template/genesis.json
}

init_wallet_node () {
  echo -ne "  -- Check Wallet daemon : "
  if [ $(node_svc_check wallet) -eq 1 ]
  then 
    echo "[ SKIP ]"
    echo "  -- Wallet(keosd) is already running."
    echo "  -- WALLET HOST : $WALLET_HOST / WALLET PORT : $WALLET_PORT"
    return 1
  else
    if [ -d $WALLET_DIR ]
    then
      echo "[ SKIP ]"
      echo "  -- wallet directory is already exists! "
      echo "     Starting keosd. wait 5 secs ... "
      $WALLET_DIR/run.sh start
      return 1
    else
      echo_s
      make_dir $WALLET_DIR
      echo "  -- Create wallet config"
      sed -e "s/__WALLET_HOST__/${WALLET_HOST}/g" \
          -e "s/__WALLET_PORT__/${WALLET_PORT}/g" \
          -e "s+__WALLET_DIR__+${WALLET_DIR}+g" < $DATA_DIR/template/wallet.config > $WALLET_DIR/config.ini
  
      sed -e "s+__DATA__+${WALLET_DIR}+g" \
          -e "s+__BIN__+${EOS_BIN}/keosd/keosd+g" \
          -e "s/__PROG__/keosd/g" < $DATA_DIR/template/run.sh > $WALLET_DIR/run.sh
      chmod 0755 $WALLET_DIR/run.sh
      echo "  -- Start wallet Node"
      $WALLET_DIR/run.sh start
    fi
  fi 
}

migration_snapshot() {
  CNT=0
  if [ -f $SNAPSHOT_FILE ] 
  then
    T_END=$(cat $SNAPSHOT_FILE | wc -l)
    [ $SNAPSHOT_BREAK -ne 0 ] && T_END=$SNAPSHOT_BREAK
    echo "  -- Migration ERC-20 Token to EOS Coin"
    echo "     If you want to watching migration then run below command on other terminal"
    echo "     > tail -f $DATA_DIR/boot/migration.log"
    sleep 1
    echo "EOS Account,EOS Public Key,EOS Balacne,ERC-20 KEy" > $DATA_DIR/boot/migration_$(date +%Y%m%d).csv
    cat $SNAPSHOT_FILE | sed "s/\"//g" | while IFS=, read ERCKEY EOS_PUBKEY AMOUNT; do
      ((CNT++))
      [ $SNAPSHOT_BREAK -eq $CNT ] && break;
      ProgressBar ${CNT} ${T_END}
      while true; do
        R_PRE=$(tr -cd 'abcdefghijklmnopqrstuvwxyz12345' < /dev/urandom | fold -w 6 | head -n1)a
        $CLE get account $SNAPSHOT_ACCOUNT_PREFIX$R_PRE >> /dev/null 2>&1
        [ $? -eq 1 ] && break;
      done
      # Snapshot account staked amount value checker
      echo -ne "   --- Create snapshot account - $SNAPSHOT_ACCOUNT_PREFIX$R_PRE : "  >> $DATA_DIR/boot/migration.log 2>&1 
      $CLE system newaccount eosio $SNAPSHOT_ACCOUNT_PREFIX$R_PRE $EOS_PUBKEY $EOS_PUBKEY --stake-net "1000.0000 $CUR_SYM" --stake-cpu "1000.0000 $CUR_SYM" >> $DATA_DIR/boot/stdout.txt 2>&1
      [ $? -eq 0 ] && echo_s >> $DATA_DIR/boot/migration.log  || echo_f >> $DATA_DIR/boot/migration.txt
  
      # Migration EOS amount to EOS Account
      echo -ne "   --- Migration EOS Token to EOS Coin - $SNAPSHOT_ACCOUNT_PREFIX$R_PRE : " >> $DATA_DIR/boot/migration.log 2>&1 
      $CLE push action eosio.token transfer '["eosio","'$SNAPSHOT_ACCOUNT_PREFIX$R_PRE'","'$AMOUNT' '$CUR_SYM'","Snapshot migration - eosio to '$SNAPSHOT_ACCOUNT_PREFIX$R_PRE'"]' -p eosio >> $DATA_DIR/boot/stdout.txt 2>&1 
      [ $? -eq 0 ] && echo_s >> $DATA_DIR/boot/migration.log  || echo_f >> $DATA_DIR/boot/migration.txt
  
      # Set Priv to EOS Migration Account
      #echo -ne  "   --- Set Privileges on $SNAPSHOT_ACCOUNT_PREFIX$R_PRE : " >> $DATA_DIR/boot/migration.log 2>&1 
      #$CLE push action eosio setpriv '{"account":"'$SNAPSHOT_ACCOUNT_PREFIX$R_PRE'","is_priv":1}' -p eosio >> $DATA_DIR/boot/migration.log 2>&1
      #[ $? -eq 0 ] && echo_s >> $DATA_DIR/boot/migration.log  || echo_f >> $DATA_DIR/boot/migration.txt
      _NOW_AMOUNT=$($CLE get currency balance eosio.token $SNAPSHOT_ACCOUNT_PREFIX$R_PRE "SYS")
      echo "$SNAPSHOT_ACCOUNT_PREFIX$R_PRE,$EOS_PUBKEY,$AMOUNT,$_NOW_AMOUNT,$ERCKEY" >> $DATA_DIR/boot/migration_$(date +%Y%m%d).csv
      unset _STAKED _STAKE_CPU _STAKE_NET
    done
  fi
}

node_svc_check () {
  if [ $1 == "wallet" ] 
  then 
    CHK_SVC=$(curl -Is http://${WALLET_HOST}:${WALLET_PORT}/v1/wallet/list_wallets | head -n 1 | grep HTTP | wc -l)
  else
    CHK_SVC=$(curl -Is http://$1/v1/chain/get_info | head -n 1 | grep HTTP | wc -l)
  fi
  echo $CHK_SVC
  [ $CHK_SVC -eq 1 ] && return 1 || return 0
}

init_boot_node () {
  [ ! -d $KEY_DIR ] && make_dir $KEY_DIR
  echo -ne "  -- Check Boot node : "
  if [ $(node_svc_check "${BOOT_HOST}:${BOOT_HTTP}") -eq 1 ]
  then
    echo "[ SKIP ]"
    echo "  -- BOOT Node is already running."
    echo "  -- BOOT HOST : $BOOT_HOST / BOOT PORT : $BOOT_HTTP"
    return 1
  elif [ -d $DATA_DIR/boot ]
  then
    echo "[ SKIP ]"
    echo "  -- Boot node directory is already exists!"
    return 1
  else
    echo_s
    make_dir  $DATA_DIR/boot
  fi
  echo -ne "  -- Create eosio acount Keys : "
  $CLE create key > $DATA_DIR/boot/boot.bpkey
  $CLE create key > $DATA_DIR/boot/msig.bpkey
  $CLE create key > $DATA_DIR/boot/token.bpkey
  [ -f $DATA_DIR/boot/boot.bpkey ] && echo_s || echo_fx
  echo "  -- Create boot config"
  INIT_DATE=$(date +"%Y-%m-01T00:00:00")
  PUB_KEY=$(cat $DATA_DIR/boot/boot.bpkey | grep -i "public" | awk '{print $3}')
  PRIV_KEY=$(cat $DATA_DIR/boot/boot.bpkey | grep -i "private" | awk '{print $3}')

  # SET config.ini for boot node
  sed -e "s/__PRIVKEY__/$PRIV_KEY/g" \
  -e "s/__BOOT_HOST__/$BOOT_HOST/g" \
  -e "s/__BOOT_HTTP__/$BOOT_HTTP/g" \
  -e "s/__BOOT_P2P__/$BOOT_P2P/g" \
  -e "s/__PUBKEY__/$PUB_KEY/g" < $DATA_DIR/template/config.boot  > $DATA_DIR/boot/config.ini

  # SET Genesis.json for boot node
  sed -e "s/__PUBKEY__/$PUB_KEY/g" \
  -e "s/__INIT_DATE__/$INIT_DATE/g" < $DATA_DIR/template/genesis.boot > $DATA_DIR/boot/genesis.json

  # SET run.sh for boot node
  sed -e "s+__DATA__+$DATA_DIR/boot+g" \
      -e "s/__PROG__/nodeos/g" < $DATA_DIR/template/run.sh > $DATA_DIR/boot/run.sh
  chmod 0755 $DATA_DIR/boot/run.sh
  # Copy default genesis.json 
  cp -a $DATA_DIR/boot/genesis.json $DATA_DIR/template/genesis.json
  echo  "  -- Start node : "
  $DATA_DIR/boot/run.sh start
  echo "  -- Wait 2 sec..."
  sleep 2

  $CLE wallet create > $DATA_DIR/boot/boot.wpk
  echo_ret "  -- Create eosio Wallet : " $?
  
  $CLE wallet import "$PRIV_KEY" >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Import eosio(default) Key : " $?
  
  PUB_TOKEN=$(cat $DATA_DIR/boot/token.bpkey | grep -i "public" | awk '{print $3}')
  PRIV_TOKEN=$(cat $DATA_DIR/boot/token.bpkey | grep -i "private" | awk '{print $3}')
  PUB_MSIG=$(cat $DATA_DIR/boot/msig.bpkey | grep -i "public" | awk '{print $3}')
  PRIV_MSIG=$(cat $DATA_DIR/boot/msig.bpkey | grep -i "private" | awk '{print $3}')

  $CLE set contract eosio $SRC_DIR/build/contracts/eosio.bios/  >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Set Contract eosio.bios :" $?

  $CLE wallet create -n eosio.token > $DATA_DIR/boot/eosio.token.wpk
  echo_ret "  -- Create eosio.token Wallet : " $?
 
  $CLE wallet import -n eosio.token "$PRIV_TOKEN" >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Import eosio.token Key : " $?

  $CLE create account eosio eosio.token $PUB_TOKEN $PUB_TOKEN >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Create eosio.token account in block : " $?

  $CLE wallet create -n eosio.msig > $DATA_DIR/boot/eosio.msig.wpk
  echo_ret "  -- Create eosio.msig Wallet : " $?
  
  $CLE wallet import -n eosio.msig "$PRIV_MSIG" >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Import eosio.msig Key : " $?

  $CLE create account eosio eosio.msig $PUB_MSIG $PUB_MSIG >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Create eosio.msig account in block : " $?

  $CLE set contract eosio.token $SRC_DIR/build/contracts/eosio.token/ -p eosio.token  >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Set Contract eosio.token :" $?

  $CLE set contract eosio.msig $SRC_DIR/build/contracts/eosio.msig/ -p eosio.msig  >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Set Contract eosio.msig :" $?
 
  $CLE push action eosio.token create '[ "eosio", "10000000000.0000 '$CUR_SYM'", 0, 0, 0]' -p eosio.token  >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Create EOS Token :" $?

  $CLE push action eosio.token issue '["eosio","1000000000.0000 '$CUR_SYM'","Inittialize EOS Token"]' -p eosio  >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Issue EOS Token to eosio :" $?

    # Set Appointment Node on bootnode (it's for test only)
  printf '{\n  "version": "%s",\n  "schedule": [\n' $(date +%s) > $BP_PROD 
  for INF in a b c d e f g h i j k l m n o p q r s t u;do

    #$CLE system newaccount eosio apnode.${INF} ${PUB_KEY} --stake-net "1000.0000 $CUR_SYM" --stake-cpu "1000.0000 $CUR_SYM" --transfer  >> $DATA_DIR/boot/stdout.txt 2>&1
    $CLE create account eosio apnode.${INF} ${PUB_KEY} ${PUB_KEY} >> $DATA_DIR/boot/stdout.txt 2>&1
    echo_ret "   --- Create Appointment producer node account - apnode.${INF} : " $?

    if [ $INF == "u" ]; then 
      printf '    {"producer_name":"%s","block_signing_key":"%s"}\n' apnode.${INF} ${PUB_KEY} >> $BP_PROD
    else
      printf '    {"producer_name":"%s","block_signing_key":"%s"},\n' apnode.${INF} ${PUB_KEY} >> $BP_PROD
    fi
  done
  echo "  ]}" >> $BP_PROD
  sleep 1
  # Run setprod push 
  bp_action
  echo -n "  -- Wait Appointment BP Node turn : "
  while true; do
    [ $(tail -n 2 $DATA_DIR/boot/stderr.txt | grep -e "signed by apnode\.[a-z]" | wc -l ) -ne 0 ] && break;
  done
  echo_s

  $CLE push action eosio setpriv '{"account":"eosio","is_priv":1}' -p eosio >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Set Privileges on eosio : " $?

  $CLE push action eosio setpriv '{"account":"eosio.msig","is_priv":1}' -p eosio >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Set Privileges on eosio.msig : " $?

  $CLE push action eosio setpriv '{"account":"eosio.token","is_priv":1}' -p eosio >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Set Privileges on eosio.token : " $?

  # make cleos.sh
  echo '#!/bin/bash
  '$EOS_BIN'/cleos/cleos -u http://'$BOOT_HOST':'$BOOT_HTTP' --wallet-url=http://'${WALLET_HOST}':'${WALLET_PORT}' "$@"' > $DATA_DIR/boot/cleos.sh
  chmod +x $DATA_DIR/boot/cleos.sh

  # Set System Contract on eosio
  $CLE set contract eosio $SRC_DIR/build/contracts/eosio.system -p eosio >> $DATA_DIR/boot/stdout.txt 2>&1
  if [ $? -eq 1 ]; then
    $CLE set contract eosio $SRC_DIR/build/contracts/eosio.system -p eosio >> $DATA_DIR/boot/stdout.txt 2>&1
    echo_ret "  -- Update eosio.system Contracts for eosio : " $?
  else
    echo_ret "  -- Update eosio.system Contracts for eosio : " 0
  fi

  # Migrate ERC-20 Token to EOS Coin on mainnet
  [ $LOAD_SNAPSHOT -eq 1 ] && migration_snapshot
  echo


  echo "================================================================================"
  echo "  -- Check $CUR_SYM Token"
  echo "================================================================================"
  echo " Account : eosio / currency : $($CLE get currency balance eosio.token eosio $CUR_SYM)"
  echo "================================================================================"
  echo "  -- Check Block status"
  echo "================================================================================"
  $CLE get info
  echo "================================================================================"
}

setup_env () {
  echo "  -- cleos alias script settings are run as root with the sudo command." 
  sed -e "s+__NODE_CONF__+$(pwd)/$conf_file+g" -e "s+__BIN__+$EOS_BIN+g" < $DATA_DIR/template/eos_env.sh > $DATA_DIR/template/eos_env.tmp
  sudo mv $DATA_DIR/template/eos_env.tmp /etc/profile.d/eos_env.sh
  [ $? -eq 0 ] && echo -e "   --- Copy to /etc/profile.d/eos_env.sh : \033[1;32m[ Success ]\033[0m" || echo " --- Copy to /etc/profile.d/eos_env.sh : \033[1;31m[ Failed ]\033[0m"
  echo "  -- run to this : source /etc/profile.d/eos_env.sh; eos_env;"
}

unset_env () {
  echo " -- Remove cleos alias script from /etc/profile.d/ "
  [ -f /etc/profile.d/eos_env.sh ] && sudo rm -f /etc/profile.d/eos_env.sh
  [ $? -eq 0 ] && echo -e "   --- Remove : \033[1;32m[ Success ]\033[0m\n   --- Run the Comamnd \"unset -f eos_env\"" || echo -e "   --- Remove : \033[1;31m[ Failed ]\033[0m"
} 


add_node_config () {
  while true; 
  do
    dup_flg=1
    echo "  -- Please enter the information for the new node."
    echo "   --- The BP Node name must be 12 characters(allowed [a-z][1-5] only)."
    read -p "   --- [1/9] BP Node Name      [eosio] : " _bpname
    read -p "   --- [2/9] BP Node Host  [localhost] : " _node_host
    read -p "   --- [3/9] BP Node HTTP Port  [8888] : " _node_http
    read -p "   --- [4/9] BP Node SSL Port    [443] : " _node_ssl
    read -p "   --- [5/9] BP Node P2P Port   [9876] : " _node_p2p
    read -p "   --- [6/9] BP Organisation [EOSeoul] : " _bp_org
    read -p "   --- [7/9] BP Location [Seoul,Korea] : " _bp_location
    read -p "   --- [8/9] BP Site URL  [eoseoul.io] : " _bp_siteurl
    read -p "   --- [9/9] BP Server ?        [true] : " _bp_isbpnode
    _bpname=${_bpname:-"eosio"}
    _node_host=${_node_host:-"localhost"}
    _node_http=${_node_http:-"8888"}
    _node_ssl=${_node_ssl:-"8888"}
    _node_p2p=${_node_p2p:-"9876"}
    _bp_org=${_bp_org:-"EOSeoul"}
    _bp_location=${_bp_location:-"Seoul,Korea"}
    _bp_siteurl=${_bp_siteurl:-"eoseoul.io"}
    _bp_isbpnode=${_bp_isbpnode:-"true"}
  
    echo "  -- Check duplicate contents with exist config"
    for((x=1;x<=${#PDNAME[@]};x++));
    do
    eval $( awk -F"|" '{print "PNAME=\""$1"\" HOSTNAME="$2" HTTP_PORT="$3" P2P_PORT="$4" SSL_PORT="$5" ORG=\""$6"\" LOCALE=\""$7"\""}' <<< ${PDNAME[$x]} )
      if [ $PNAME == $_bpname ] 
      then 
         printf "\033[1;31m%s\033[0m\n"  "   --- BPName is duplicate "
         dup_flg=0
         break;
      elif [ $HTTP_PORT == $_node_http ]
      then 
         printf "\033[1;31m%s\033[0m\n"  "   --- BP HTTP Port is duplicate "
         dup_flg=0
         break;
      elif [ $P2P_PORT == $_node_p2p ]
      then 
         printf "\033[1;31m%s\033[0m\n"  "   --- BP P2P Port is duplicate "
         dup_flg=0
         break;
      fi
    done
    if [ $dup_flg -eq 1 ]
    then
      echo -ne "   --- Adding BP node config : "
      echo_s
      echo "PDNAME[_v++]=\"${_bpname}|${_node_host}|${_node_http}|${_node_p2p}|${_node_ssl}|${_bp_org}|${_bp_location}|${_bp_siteurl}|${_bp_isbpnode}\"" >> $conf_file
      source $conf_file
      read -p "   --- Are you want to add more? [Y/n] : " _chkval
      case "${_chkval}" in
          N|n)
            return 0
          ;;
      esac
    else
      read -p "   --- Retry it again? [Y/n] : " _chkval
      case "${_chkval}" in
          N|n)
            return 1
          ;;
      esac
    fi
  done
}

case "$1" in
    single)
        check_os
        init_bp_node
        ;;
    testnet)
        check_os
        source_check
        init_wallet_node
	init_boot_node
        init_bp_node
        node_control start
        echo_end
        ;;
    boot)
        check_os
        source_check
        init_wallet_node
	init_boot_node
        echo_end
        ;;
    wallet)
        check_os
        init_wallet_node
        ;;
    addconfig)
        check_os
        add_node_config
        ;;
    clean)
        check_os
        clean_all
        ;;
    setenv)
        setup_env
        ;;
    unsetenv)
        unset_env
        ;;
    *)
        echo_head
	echo
        echo $"Usage: $0 [ command ]"
	echo 
	echo $" [ command ]"
        echo $"  - boot            : install boot node for private testnet initialize"
        echo $"  - wallet          : install local wallet daemon"
        echo $"  - testnet         : install boot node and bp nodes for private testnet"
        echo $"  - addconfig       : add node config to node_setup.conf "
        echo $"  - clean           : remove all node directory and config files"
        echo $"  - setenv          : cleos alias script set on profile"
        echo $"  - unsetenv        : cleos alias script unset on profile"
	echo
        RETVAL=2
esac

exit $RETVAL
