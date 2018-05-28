#!/bin/bash
DATADIR=__DATA__
BINDIR=__BIN__
PROG=nodeos

echo_s ()
{
  printf "\033[1;32m[ Success ]\033[0m\n"
}
echo_f ()
{
  printf "\033[1;31m[ failed ]\033[0m\n"
}
echo_fx ()
{
  printf "\033[1;31m[ failed ]\033[0m\n";
  exit 1;
}

_init_start() {
  if [ -f ${DATADIR}/${PROG}.pid ]; then
    _pid=`cat ${DATADIR}/${PROG}.pid`
    if [ -d "/proc/${_pid}" ]; then
      echo "   --- $(basename $DATADIR) node is running now."
      return 1
    fi
  fi
  
  if [ ! -d ${DATADIR}/blocks ]; then
    echo -ne "   --- Initial Starting Node - $(basename $DATADIR) : "
    [ ! -f $DATADIR/genesis.json ] && $BINDIR/${PROG} --data-dir $DATADIR --config-dir $DATADIR --extract-genesis-json $DATADIR/genesis.json
    $BINDIR/${PROG} --data-dir $DATADIR --config-dir $DATADIR --delete-all-blocks --genesis-json $DATADIR/genesis.json "$@" >> $DATADIR/stdout.txt 2>> $DATADIR/stderr.txt & echo $! > $DATADIR/${PROG}.pid
  fi
  [ $? -eq 0 ] && echo_s || echo_f
}

_start() {
  _stop
  if [ -f ${DATADIR}/${PROG}.pid ]; then
    _pid=`cat ${DATADIR}/${PROG}.pid`
    if [ -d "/proc/${_pid}" ]; then
      echo "   --- $(basename $DATADIR) node is running now."
      return 1
    fi
  fi
  echo -ne "   --- Starting Node - $(basename $DATADIR) : "
  $BINDIR/${PROG} --data-dir $DATADIR --config-dir $DATADIR "$@" >> $DATADIR/stdout.txt 2>> $DATADIR/stderr.txt & echo $! > $DATADIR/${PROG}.pid
  [ $? -eq 0 ] && echo_s || echo_f
}

_stop() {
  if [ -f ${DATADIR}/${PROG}.pid ]; then
    _pid=`cat ${DATADIR}/${PROG}.pid`
    kill ${_pid}
    rm -r $DATADIR"/${PROG}.pid"
    echo -ne "   --- Stoping ${PROG} - $(basename $DATADIR) : "
    while true; do
      [ ! -d "/proc/$_pid/fd" ] && break
      echo -ne ". "
      sleep 1
    done
    echo_s 
  fi
}

case "$1" in
    start)
        _start "$@"
        ;;
    stop)
        _stop
        ;;
    init)
        _init_start
        ;;
    restart)
        _stop
        _start
        ;;
    *)
        echo $"Usage: $0 {start|stop|restart} {extended argv}"
        RETVAL=2
esac

exit $RETVAL
