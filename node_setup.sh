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

function ProgressBar_verify {
    let _progress=(${1}*100/${2}*100)/100
    let _done=(${_progress}*4)/10
    let _left=40-$_done
    _fill=$(printf "%${_done}s")
    _empty=$(printf "%${_left}s")

    printf "\r   Progress : [${_fill// /#}${_empty// /-}] ${_progress}%% (${1}/${2}) (Success: ${3} / Failed: ${4} / Diff Amount : ${5})"
}

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
  echo "  -- Check Requried package"
  DPKG="jq" 
  for pkg in $DPKG; do 
    if [ -z $( dpkg -s jq 2>/dev/null | grep "Status" | awk '{print $4}') ]; then
      sudo apt-get -y install $pkg
    fi
  done
  echo "  -- Check EOS Source file"
  rp_chk=$(git ls-remote $GIT_REPO |  egrep "(heads|tags)/$EOS_RELEASE" | wc -l)
  if [ $rp_chk -eq 0 ] 
  then
    echo "  -- Git Repo or Release is not available. check EOS_RELEASE in $conf_file"
    exit 1
  fi

  if [ ! -d $SRC_DIR ]; then
    git clone http://github.com/eosio/eos $SRC_DIR --recursive
    pushd $SRC_DIR > /dev/null; 
    git checkout -f $EOS_RELEASE; 
    git submodule update --recursive; 
    #Set CORE Token Symbol
    CUR_SYM=${CUR_SYM:-"EOS"}
    if [ $(grep "CORE_SYMBOL_NAME" $SRC_DIR/CMakeLists.txt | grep "set" | grep "$CUR_SYM" | wc -l) -eq 0 ]; then
      echo "  -- Patch CORE Symbol - $CUR_SYM"
       sed -i.bak '16i set( CORE_SYMBOL_NAME "EOS" )' $SRC_DIR/CMakeLists.txt
    fi
    ./eosio_build.sh
    popd > /dev/null
  else
    pushd $SRC_DIR > /dev/null ; 
    if [ $(git branch | grep $EOS_RELEASE | wc -l) -eq 0 ]; then 
      git checkout master; git pull; 
      git checkout -f $EOS_RELEASE; 
      git submodule update --recursive; 
      #Set CORE Token Symbol
      CUR_SYM=${CUR_SYM:-"EOS"}
      if [ $(grep "CORE_SYMBOL_NAME" $SRC_DIR/CMakeLists.txt | grep "set" | grep "$CUR_SYM" | wc -l) -eq 0 ]; then
        echo "  -- Patch CORE Symbol - $CUR_SYM"
        sed -i.bak '16i set( CORE_SYMBOL_NAME "EOS" )' $SRC_DIR/CMakeLists.txt
      fi
      ./eosio_build.sh
    fi
    popd > /dev/null 
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
        -e "s+__BIN__+$EOS_BIN/nodeos+g" \
        -e "s/__PROG__/nodeos/g"  < $DATA_DIR/template/nodeos.sh > $DATA_DIR/td_node_$PNAME/run.sh
    chmod 0755 $DATA_DIR/td_node_$PNAME/run.sh
    # Copy Default genesis.json to BP node dir
    cp -a $DATA_DIR/template/genesis.json  $DATA_DIR/td_node_$PNAME/genesis.json
    if [ $IsBP == "true" ]; then
      # DEFINE PEER Informations
      [ -z $PPL ] && PPL="p2p-peer-address=${HOSTNAME}:${P2P_PORT}" || PPL="$PPL\np2p-peer-address=${HOSTNAME}:${P2P_PORT}"
    fi
    if [ $BNET_USE == 1 ]; then
      [ -z $BNETLIST ] && BNETLIST="bnet-connect=${HOSTNAME}:${BNET_PORT}" || BNETLIST="$BNETLIST\nbnet-connect=${HOSTNAME}:${BNET_PORT}"
    fi
    # Create EOS BP Account on EOS Blockchain
    echo -ne "  -- Create account - $PNAME : "
    $CLE system newaccount --buy-ram-kbytes 1024 --stake-net "10000.0000 ${CUR_SYM}" --stake-cpu "10000.0000 ${CUR_SYM}" eosio $PNAME $PUB_KEY $PUB_KEY >> $DATA_DIR/td_node_$PNAME/stdout.txt 2>&1
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
	$_CLE system voteproducer prods '$PNAME' '$PNAME'
        $_CLE system listproducers' >> $DATA_DIR/td_node_$PNAME/regproducer.sh
    chmod u+x $DATA_DIR/td_node_$PNAME/regproducer.sh
  fi
done

# Set P2P Peer List on config.ini
for((x=1;x<=${#PDNAME[@]};x++));
do
  PNAME=$( awk -F"|" '{print $1}' <<< ${PDNAME[$x]})
  perl -p  -i -e "s/#__P2P_PEER_LIST__/$PPL/g" $DATA_DIR/td_node_$PNAME/config.ini
  # Check BNET Enable
  if [ $BNET_USE -eq 1 ]
  then
    BNET_THREAD=$(($(cat /proc/cpuinfo | grep processor | wc -l)/2))
    [ $BNET_THREAD -eq 0 ] && BNET_THREAD=1
    echo 'plugin = eosio::bnet_plugin
bnet-endpoint = 0.0.0.0:'$BNET_PORT'
bnet-threads = '$BNET_THREAD'
'$BNETLIST'
bnet-no-trx = false' >> $DATA_DIR/boot/config.ini
  fi
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
          $DATA_DIR/td_node_${PNAME}/run.sh $1
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
          -e "s+__BIN__+${EOS_BIN}/keosd+g" \
          -e "s/__PROG__/keosd/g" < $DATA_DIR/template/run.sh > $WALLET_DIR/run.sh
      chmod 0755 $WALLET_DIR/run.sh
      echo "  -- Start wallet Node"
      $WALLET_DIR/run.sh start
    fi
  fi 
}

migration_fastsnap() {
  echo "  -- Migration ERC-20 Token to EOS Coin"
  global_param=$($CLE get table eosio eosio global | jq '.rows[0]')
  echo '{"params":'$(echo $global_param | jq '.max_block_cpu_usage=100000000 | .max_transaction_cpu_usage=99999899')'}' > $DATA_DIR/boot/mig_tmp.json
  $CLE push action eosio setparams $DATA_DIR/boot/mig_tmp.json -p eosio >> $DATA_DIR/boot/stdout.txt 2>&1
  CNT=0
  TR_SUM=0
  TRX_LIMIT=90
  TMP_KEY="EOS53Vfu5SoZLKfFDL9DeUyJaHBPSuCXNwhsAUnkzgsB5qMQQcxJY"
  TMP_ACCOUNT="tmpaccountaa"
  ACT_TEMPLATE=$($CLE system newaccount eosio $TMP_ACCOUNT $TMP_KEY $TMP_KEY --stake-net "0.4500 $CUR_SYM" --stake-cpu "0.4500 $CUR_SYM" --buy-ram-kbytes 8 -j -d -s 2>/dev/null| jq 'del(.actions) | .actions=[]' 2>&1)
  if [ -f $SNAPSHOT_FILE ] 
  then
    [ -z $RECHARGE ] && RECHARGE=0
    T_END=$(cat $SNAPSHOT_FILE | wc -l)
    [ $SNAPSHOT_BREAK -ne 0 ] && T_END=$SNAPSHOT_BREAK
    while IFS=, read ERCKEY EOS_ACCOUNT EOS_PUBKEY AMOUNT; do
      ((CNT++))
      # Make TRX json
      ACT=$($CLE system newaccount eosio $EOS_ACCOUNT $EOS_PUBKEY $EOS_PUBKEY --stake-net "0.4500 $CUR_SYM" --stake-cpu "0.4500 $CUR_SYM" --buy-ram-kbytes 8 -j -d -s 2>/dev/null| jq -c '.actions' )
      TR_ACT=$($CLE push action eosio.token transfer '["eosio","'$EOS_ACCOUNT'","'$AMOUNT' '$CUR_SYM'","Snapshot migration - eosio to '$EOS_ACCOUNT'"]' -p eosio -j -d -x 2>/dev/null | jq -c '.actions')
      ACT_TEMPLATE=$(echo $ACT_TEMPLATE | jq '.actions+='$ACT )
      ACT_TEMPLATE=$(echo $ACT_TEMPLATE | jq '.actions+='$TR_ACT )

      if [ $(echo $CNT%$TRX_LIMIT|bc) -eq 0 ];then
        echo "$ACT_TEMPLATE" > $DATA_DIR/boot/mig_tmp.json
        $CLE sign -k $PRIV_KEY -p $DATA_DIR/boot/mig_tmp.json >> $DATA_DIR/boot/fast_migration.log 2>&1 &

        ACT_TEMPLATE=$($CLE system newaccount eosio $TMP_ACCOUNT $TMP_KEY $TMP_KEY --stake-net "0.4500 $CUR_SYM" --stake-cpu "0.4500 $CUR_SYM" --buy-ram-kbytes 8 -j -d -s 2>/dev/null| jq 'del(.actions) | .actions=[]' 2>&1)
      fi
      ProgressBar ${CNT} ${T_END}
      [ $SNAPSHOT_BREAK -eq $CNT ] && break;
    done < <( cat $SNAPSHOT_FILE | sed "s/\"//g" )
    # Last Commit
    $CLE sign -k $PRIV_KEY -p "$ACT_TEMPLATE" >> $DATA_DIR/boot/fast_migration.log 2>&1
    echo
    echo
    rm -f $DATA_DIR/boot/mig_tmp.json
  fi
}


migration_snapshot() {
  CNT=0
  TR_SUM=0
  if [ -f $SNAPSHOT_FILE ] 
  then
    [ -z $RECHARGE ] && RECHARGE=0
    T_END=$(cat $SNAPSHOT_FILE | wc -l)
    [ $SNAPSHOT_BREAK -ne 0 ] && T_END=$SNAPSHOT_BREAK
    echo "  -- Migration ERC-20 Token to EOS Coin"
    echo "     If you want to watching migration then run below command on other terminal"
    echo "     > tail -f $DATA_DIR/boot/migration.log"
    sleep 1
    echo "EOS Account,EOS Public Key,EOS Balacne,ERC-20 KEy" > $DATA_DIR/boot/migration_$(date +%Y%m%d).csv
    while IFS=, read ERCKEY EOS_ACCOUNT EOS_PUBKEY AMOUNT; do
      ((CNT++))
      # Get past currency balance from eosio
      PAST_BALANCE=$($CLE get currency balance eosio.token eosio | sed "s/ EOS//g")
      # Purchase the CPU, Bandwidth, and Ram required to create an account using the eosio account.
      echo -ne "   --- Create snapshot account - $EOS_ACCOUNT : "  >> $DATA_DIR/boot/migration.log 2>&1 
      $CLE system newaccount eosio $EOS_ACCOUNT $EOS_PUBKEY $EOS_PUBKEY --stake-net "0.4500 $CUR_SYM" --stake-cpu "0.4500 $CUR_SYM" --buy-ram-kbytes 8 >> $DATA_DIR/boot/stdout.txt 2>&1 
      [ $? -eq 0 ] && echo_s >> $DATA_DIR/boot/migration.log  || echo_f >> $DATA_DIR/boot/migration.txt

      # Get now currency balance from eosio
      NOW_BALANCE=$($CLE get currency balance eosio.token eosio | sed "s/ EOS//g")
      DIF_BALANCE=$(echo "scale=5; $PAST_BALANCE - $NOW_BALANCE" | bc)
      RECHARGE=$(echo "scale=5;$RECHARGE + $DIF_BALANCE" | bc)
      echo  "    ---- EOSIO Balance change : $PAST_BALANCE EOS -> $NOW_BALANCE EOS (Out $DIF_BALANCE EOS / Total -$RECHARGE EOS)" >> $DATA_DIR/boot/migration.txt
      # Migration EOS amount to EOS Account
      echo $CLE push action eosio.token transfer '["eosio","'$EOS_ACCOUNT'","'$AMOUNT' '$CUR_SYM'","Snapshot migration - eosio to '$EOS_ACCOUNT'"]' -p eosio >> $DATA_DIR/boot/stdout.txt 2>&1 
      $CLE push action eosio.token transfer '["eosio","'$EOS_ACCOUNT'","'$AMOUNT' '$CUR_SYM'","Snapshot migration - eosio to '$EOS_ACCOUNT'"]' -p eosio >> $DATA_DIR/boot/stdout.txt 2>&1 
      [ $? -eq 0 ] && echo_s >> $DATA_DIR/boot/migration.log  || echo_f >> $DATA_DIR/boot/migration.txt

      TR_SUM=$(echo "scale=5;$TR_SUM+$AMOUNT" | bc)
      _NOW_AMOUNT=$($CLE get currency balance eosio.token $EOS_ACCOUNT $CUR_SYM | sed "s/ EOS//g")
      ProgressBar ${CNT} ${T_END} ${DIF_BALANCE} ${RECHARGE}
      echo "$EOS_ACCOUNT,$EOS_PUBKEY,$AMOUNT,$_NOW_AMOUNT,$ERCKEY" >> $DATA_DIR/boot/migration_$(date +%Y%m%d).csv
      [ $SNAPSHOT_BREAK -eq $CNT ] && break;
    done < <( cat $SNAPSHOT_FILE | sed "s/\"//g" )
    echo;echo
    echo -ne "  -- Recharge used coin for create migration accounts (${RECHARGE} ${CUR_SYM}) : "
    $CLE push action eosio.token issue '["eosio","'${RECHARGE}' '${CUR_SYM}'" "Recharge EOS token for create account used"]' -p eosio >> $DATA_DIR/boot/stdout.txt 2>&1
    [ $? -eq 0 ] && echo_s 
    echo
    echo "################################################################################"
    echo 
    echo "   - Snapshot cccount count   : $(cat $SNAPSHOT_FILE | wc -l)"
    echo "   - Migration account count  : ${CNT} "
    echo "   - Used balance for create  : $RECHARGE EOS"
    echo "   - Transfer amount          : ${TR_SUM}"
    echo "   - EOSIO Account Balance    : $($CLE get currency balance eosio.token eosio EOS)"
    echo "   - Migration Verify DIFF    : $DIF_BALANCE EOS"
    echo 
    echo "################################################################################"a
    echo
    echo
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
}

migration_verify() {
  CNT=0
  S_CNT=0
  F_CNT=0
  S_AMT=0
  C_AMT=0
  if [ -f $SNAPSHOT_FILE ] 
  then
    T_END=$(cat $SNAPSHOT_FILE | wc -l)
    [ $SNAPSHOT_BREAK -ne 0 ] && T_END=$SNAPSHOT_BREAK
    echo "  -- Migration verify"
    while IFS=, read ERCKEY EOS_ACCOUNT EOS_PUBKEY AMOUNT; do
      ((CNT++))
      # Get past currency balance from eosio
      verify_balance=$($CLE get currency balance eosio.token $EOS_ACCOUNT | sed "s/ EOS//g")
      if [ "$verify_balance" == "$AMOUNT" ]; then
        ((S_CNT++))
      else 
        ((F_CNT++))
      fi
      C_AMT=$(echo "scale=5;$S_AMT + $verify_balance" | bc)
      S_AMT=$(echo "scale=5;$S_AMT + $AMOUNT" | bc)
      AMT_DIF=$(echo "scale=5;$S_AMT - $C_AMT"| bc)

      ProgressBar_verify ${CNT} ${T_END} ${S_CNT} ${F_CNT} ${AMT_DIF}
      [ $SNAPSHOT_BREAK -eq $CNT ] && break;
    done < <( cat $SNAPSHOT_FILE | sed "s/\"//g" )
    FR_AMT=$($CLE get currency balance eosio.token eosio | sed "s/ EOS//g")
    echo
    echo
    echo "################################################################################"
    echo 
    echo "   - Snapshot cccount count : $(cat $SNAPSHOT_FILE | wc -l)"
    echo "   - Check account count    : ${CNT} "
    echo "   - Migration All amount   : $C_AMT EOS"
    echo "   - Snapshot All amount    : $S_AMT EOS"
    echo "   - EOSIO Account Balance  : ${FR_AMT} EOS"
    echo "   - EOSIO Balance + TRansfer Balance = 1000000000"
    echo "     ==>  $FR_AMT + $C_AMT = "$(echo "scale=5;$FR_AMT+$C_AMT"|bc)
    echo "   - Migration token Verify : $AMT_DIF EOS (0 is verify success)"
    echo 
    echo "################################################################################"
    echo 
    echo 
  fi 
  rocket_goto_moon
}

rocket_goto_moon () { 
  echo "                                      #"
  sleep 0.1
  echo "                                     ###"
  sleep 0.1
  echo "                                    #####"
  sleep 0.1
  echo "                                   #######"
  sleep 0.1
  echo "                                  #########"
  sleep 0.1
  echo "                                  #########"
  sleep 0.1
  echo "                                  ##     ##"
  sleep 0.1
  echo "                                  ## ######"
  sleep 0.1
  echo "                                  ##     ##"
  sleep 0.1
  echo "                                  ## ######"
  sleep 0.1
  echo "                                  ##     ##"
  sleep 0.1
  echo "                                  #########"
  sleep 0.1
  echo "                                  #########"
  sleep 0.1
  echo "                                  ##     ##"
  sleep 0.1
  echo "                                  #  ###  #"
  sleep 0.1
  echo "                                  #  ###  #"
  sleep 0.1
  echo "                                  #  ###  #"
  sleep 0.1
  echo "                                  #  ###  #"
  sleep 0.1
  echo "                                  ##     ##"
  sleep 0.1
  echo "                                  #########"
  sleep 0.1
  echo "                                 ###########"
  sleep 0.1
  echo "                                ####      ###"
  sleep 0.1
  echo "                               ###  ##########"
  sleep 0.1
  echo "                              #####       #####"
  sleep 0.1
  echo "                             ############  #####"
  sleep 0.1
  echo "                            #######       #######"
  sleep 0.1
  echo "                           #######################"
  sleep 0.1
  echo "                          #########################"
  sleep 0.1
  echo "                                #############"
  sleep 0.1
  echo "                               ###############"
  sleep 0.1
  echo "                                 ###########"
  sleep 0.1
  echo "                                  #########"
  sleep 0.1
  echo "                                   #######"
  sleep 0.1
  echo "                                    #####"
  sleep 0.1
  echo "                                     ### "
  sleep 0.1
  echo "                                      #  "
  sleep 0.1
  echo "                                      #  "
  sleep 0.1
  echo "                                      #  "
  sleep 0.1
  echo "                                      #  "
  sleep 0.1
  echo "                                      #  "
  sleep 0.1
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

  # define system account list
  _SYSTEM_ACCOUNT="eosio.bpay eosio.msig eosio.names eosio.ram eosio.ramfee eosio.saving eosio.stake eosio.token eosio.vpay"
  # Appointment BP account prefix
  _AP_PREFIX="appointnode"
 
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

  # Check BNET Enable
  if [ $BNET_USE -eq 1 ]
  then
    BNET_THREAD=$(($(cat /proc/cpuinfo | grep processor | wc -l)/2))
    [ $BNET_THREAD -eq 0 ] && BNET_THREAD=1
    echo 'plugin = eosio::bnet_plugin
bnet-endpoint = 0.0.0.0:'$BNET_PORT'
bnet-threads = '$BNET_THREAD'
bnet-connect = localhost:'$BNET_PORT'
bnet-no-trx = false' >> $DATA_DIR/boot/config.ini
  fi

  # SET Genesis.json for boot node
  sed -e "s/__PUBKEY__/$PUB_KEY/g" \
  -e "s/__INIT_DATE__/$INIT_DATE/g" < $DATA_DIR/template/genesis.boot > $DATA_DIR/boot/genesis.json

  # SET run.sh for boot node
  sed -e "s+__DATA__+$DATA_DIR/boot+g" \
      -e "s+__BIN__+$EOS_BIN/nodeos+g" \
      -e "s/__PROG__/nodeos/g" < $DATA_DIR/template/nodeos.sh > $DATA_DIR/boot/run.sh
  chmod 0755 $DATA_DIR/boot/run.sh
  # Copy default genesis.json 
  cp -a $DATA_DIR/boot/genesis.json $DATA_DIR/template/genesis.json
  echo  "  -- Start node : "
  $DATA_DIR/boot/run.sh start --genesis-json $DATA_DIR/boot/genesis.json
  echo "  -- Wait 2 sec..."
  sleep 4

  $CLE wallet create > $DATA_DIR/boot/boot.wpk
  echo_ret "  -- Create eosio Wallet : " $?
  
  $CLE wallet import "$PRIV_KEY" >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Import eosio(default) Key : " $?
  
  $CLE set contract eosio $SRC_DIR/build/contracts/eosio.bios/  >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Set Contract eosio.bios :" $?

  # Create System Account 
  for _account_name in $_SYSTEM_ACCOUNT;
  do
    $CLE wallet create -n ${_account_name} > $DATA_DIR/boot/${_account_name}.wpk
    echo_ret "  -- Create ${_account_name} Wallet : " $?

    $CLE wallet import -n ${_account_name} "$PRIV_KEY" >> $DATA_DIR/boot/stdout.txt 2>&1
    echo_ret "  -- Import ${_account_name} Key : " $?

    $CLE create account eosio ${_account_name} $PUB_KEY $PUB_KEY >> $DATA_DIR/boot/stdout.txt 2>&1
    echo_ret "  -- Create ${_account_name} account in block : " $?

    # Set Privilege to system account.
    $CLE push action eosio setpriv '{"account":"'${_account_name}'","is_priv":1}' -p eosio >> $DATA_DIR/boot/stdout.txt 2>&1
    echo_ret "  -- Set Privileges ${_account_name} : " $?
  done

  # Regist contracts
  $CLE set contract eosio.token $SRC_DIR/build/contracts/eosio.token/ -p eosio.token  >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Set Contract eosio.token :" $?

  $CLE set contract eosio.msig $SRC_DIR/build/contracts/eosio.msig/ -p eosio.msig  >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Set Contract eosio.msig :" $?
  
  # Create Token
  $CLE push action eosio.token create '[ "eosio", "500000000000.0000 '$CUR_SYM'", 0, 0, 0]' -p eosio.token  >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Create EOS Token :" $?

  # Issue Token
  $CLE push action eosio.token issue '["eosio","1000100000.0000 '$CUR_SYM'","Inittialize EOS Token"]' -p eosio  >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Issue EOS Token to eosio :" $?

  # Set Appointment Node on bootnode (it's for test only)
  printf '{\n  "version": "%s",\n  "schedule": [\n' $(date +%s) > $BP_PROD 
  for INF in a b c d e f g h i j k l m n o p q r s t u;do

    #$CLE system newaccount eosio ${_AP_PREFIX}${INF} ${PUB_KEY} --stake-net "1000.0000 $CUR_SYM" --stake-cpu "1000.0000 $CUR_SYM" --transfer  >> $DATA_DIR/boot/stdout.txt 2>&1
    $CLE create account eosio ${_AP_PREFIX}${INF} ${PUB_KEY} ${PUB_KEY} >> $DATA_DIR/boot/stdout.txt 2>&1
    echo_ret "   --- Create Appointment producer node account - ${_AP_PREFIX}${INF} : " $?

    if [ $INF == "u" ]; then 
      printf '    {"producer_name":"%s","block_signing_key":"%s"}\n' ${_AP_PREFIX}${INF} ${PUB_KEY} >> $BP_PROD
    else
      printf '    {"producer_name":"%s","block_signing_key":"%s"},\n' ${_AP_PREFIX}${INF} ${PUB_KEY} >> $BP_PROD
    fi
  done
  echo "  ]}" >> $BP_PROD
  sleep 1
  # Run setprod push 
  bp_action
  echo -n "  -- Wait Appointment BP Node turn : "
  while true; do
    [ $(tail -n 2 $DATA_DIR/boot/stderr.txt | grep -e "signed by ${_AP_PREFIX}[a-z]" | wc -l ) -ne 0 ] && break;
  done
  echo_s

  # make cleos.sh
  echo '#!/bin/bash
  '$EOS_BIN'/cleos/cleos -u http://'$BOOT_HOST':'$BOOT_HTTP' --wallet-url=http://'${WALLET_HOST}':'${WALLET_PORT}' "$@"' > $DATA_DIR/boot/cleos.sh
  chmod +x $DATA_DIR/boot/cleos.sh

  # Set System Contract on eosio
  $CLE set contract eosio $SRC_DIR/build/contracts/eosio.system -x 300 -p eosio >> $DATA_DIR/boot/stdout.txt 2>&1
  if [ $? -eq 1 ]; then
    sleep 2;
    $CLE set contract eosio $SRC_DIR/build/contracts/eosio.system -x 300 -p eosio >> $DATA_DIR/boot/stdout.txt 2>&1
    echo_ret "  -- Update eosio.system Contracts for eosio : " $?
  else
    echo_ret "  -- Update eosio.system Contracts for eosio : " 0
  fi

  # Migrate ERC-20 Token to EOS Coin on mainnet
  if [ $LOAD_SNAPSHOT -eq 1 ]; then
    migration_snapshot
    if [ $SKIP_VERIFY -eq 0 ]; then 
      migration_verify
    fi
  fi

  # Resign
  if [ $RESIGN -eq 1 ]; then 
    # Check Load SNAPSHOT
    if [ $LOAD_SNAPSHOT -eq 1 ]; then
      # Resign Appointment account
      for INF in a b c d e f g h i j k l m n o p q r s t u;do
        resign_trx ${_AP_PREFIX}${INF}
      done
      # Resign System account
      for _account_name in $_SYSTEM_ACCOUNT; do
        resign_trx ${_account_name}
      done
      # Resign eosio account
      resign_trx eosio
    else
      # Resign nead to enable snapshot config 
      echo "  --------------------------------------------------------------------"
      echo "   If you want to resign system account,"
      echo "   plaese change LOAD_SNAPSHOT flag set 1 first"
      echo "  --------------------------------------------------------------------"
    fi
  fi
 
  echo
  echo "  -- Check $CUR_SYM Token"
  echo "================================================================================"
  echo " Account : eosio / currency : $($CLE get currency balance eosio.token eosio $CUR_SYM)"
  echo "================================================================================"
  echo "  -- Check Block status"
  echo "================================================================================"
  $CLE get info
  echo "================================================================================"
}

resign_trx () { 
  $CLE push action eosio updateauth '{"account": "'$1'", "permission": "owner",  "parent": "",  "auth": { "threshold": 1, "keys": [], "waits": [], "accounts": [{ "weight": 1, "permission": {"actor": "eosio", "permission": "active"} }] } } ' -p $1@owner >> $DATA_DIR/boot/stdout.txt 2>&1
  $CLE push action eosio updateauth '{"account": "'$1'", "permission": "active",  "parent": "owner",  "auth": { "threshold": 1, "keys": [], "waits": [], "accounts": [{ "weight": 1, "permission": {"actor": "eosio", "permission": "active"} }] } }' -p $1@active >> $DATA_DIR/boot/stdout.txt 2>&1
  echo_ret "  -- Resign ${1} account : " $?
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
        node_control init
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
