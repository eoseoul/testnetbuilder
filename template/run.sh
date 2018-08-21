#!/bin/bash
DATADIR=__DATA__
BINDIR=__BIN__
PROG=__PROG__

print_out() {
  if [ $1 -eq 1 ]; then
    printf '\033[1;39m%-75s\033[m \033[1;31m%-25s\033[m\n' " $2" "[FAILED]"
  elif [ $1 -eq 2 ]; then
    printf '\033[1;39m%-75s\033[m \033[1;39m%-25s\033[m\n' " $2" "[SKIP]"
  else
    printf '\033[1;39m%-75s\033[m \033[1;32m%-25s\033[m\n' " $2" "[OK]"
  fi
}

_start() {
  if [ -f ${DATADIR}/${PROG}.pid ]; then
    _pid=`cat ${DATADIR}/${PROG}.pid`
    if [ -d "/proc/${_pid}" ]; then
      _stop
      return 1
    fi
  fi
  if [ $PROG == "nodeos" ]; then
    if [ ! -d ${DATADIR}/blocks ]; then
      $BINDIR/${PROG} --data-dir $DATADIR --config-dir $DATADIR --delete-all-blocks --genesis-json $DATADIR/genesis.json "$@" >> $DATADIR/stdout.txt 2>> $DATADIR/stderr.txt & echo $! > $DATADIR/${PROG}.pid
      print_out $? "Initial Start $(basename $DATADIR) $PROG"
      return 0
    fi
  fi
  $BINDIR/${PROG} --data-dir $DATADIR --config-dir $DATADIR "$@" >> $DATADIR/stdout.txt 2>> $DATADIR/stderr.txt & echo $! > $DATADIR/${PROG}.pid
  print_out $? "Start $(basename $DATADIR) $PROG"
}

_stop() {
  if [ -f ${DATADIR}/${PROG}.pid ]; then
    _pid=`cat ${DATADIR}/${PROG}.pid`
    kill ${_pid}
    rm -r $DATADIR"/${PROG}.pid"
    while true; do
      [ ! -d "/proc/$_pid/fd" ] && break
      sleep 1
    done
    print_out 0 "Stop $(basename $DATADIR) $PROG"
  fi
}

case "$1" in
    start)
        _start "$@"
        ;;
    stop)
        _stop
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
