eos_env () { 
  conf_file=__NODE_CONF__
  [ -f $conf_file ] && . $conf_file
  if [ -z $DATA_DIR ]
  then
    echo "  >> Not found $conf_file. please set to environment file."
    exit 0;
  fi
  
  EOS_BIN=__BIN__
  if [ $# -lt 1 ]
  then
    echo "Usage : ${FUNCNAME[0]} [BP Name]"
    echo " - BP Name list : "
    for((x=1;x<=${#PDNAME[@]};x++));do
      echo "   > "$(awk -F"|" '{print $1}' <<< ${PDNAME[$x]})
    done
    return 1
  else
    for((x=1;x<=${#PDNAME[@]};x++));
    do
      _pname=$(echo ${PDNAME[$x]} | awk -F"|" '{print $1}')
      _node_host=$(echo ${PDNAME[$x]} | awk -F"|" '{print $2}')
      _node_http=$(echo ${PDNAME[$x]} | awk -F"|" '{print $3}')
      _wlt_host=${WALLET_HOST}
      _wlt_port=${WALLET_PORT}
      if [ $_pname == $1 ]
      then
        if [ ! $WALLET_SHARE -eq 1 ]
        then
          _wlt_host=${_node_host}
          _wlt_port=${_node_http}
        fi
        echo "=============================================="
        echo " SET alias command : cle"
        alias cle="${EOS_BIN}/cleos/cleos --url=http://${_node_host}:${_node_http} --wallet-url=http://${_wlt_host}:${_wlt_port}"
        echo " - NODE HOST    : ${_node_host}"
        echo " - NODE HTTP    : ${_node_http}"
        echo " - WALLET HOST  : ${_wlt_host}"
        echo " - NODE HOST    : ${_wlt_port}"
        echo "=============================================="
        return 0
      fi
    done
    
    echo "We can't found $1 BP name in $conf_file."
    read -p "Do you want to set up another BP node? [y/N] : " _choose
    case $_choose in 
        Y|y)
          Cont_flg=1
          ;;
        *)
          return 2
          ;;
    esac
    read -p "Input : BP Node Host [localhost] : " _node_host
    read -p "Input : BP Node HTTP Port [8888] : " _node_http
    read -p "Input : Wallet  Host [localhost] : " _wlt_host
    read -p "Input : Wallet  Port      [8888] : " _wlt_port
    _node_host=${_node_host:-"localhost"}
    _node_http=${_node_http:-"8888"}
    _wlt_host=${_wlt_host:-"localhost"}
    _wlt_port=${_wlt_port:-"8888"}
    echo " >> We set the cle alias as below"
    echo " >> cle=${EOS_BIN}/cleos/cleos --url=http://${_node_host}:${_node_http} --wallet-url=http://${_wlt_host}:${_wlt_port}"
    alias cle="${EOS_BIN}/cleos/cleos --url=http://${_node_host}:${_node_http} --wallet-url=http://${_wlt_host}:${_wlt_port}"
  fi
}
