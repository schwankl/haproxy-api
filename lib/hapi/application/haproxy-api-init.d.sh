!/bin/bash
# init script for hapi
# chkconfig: 2345 90 10
# description: Hapi

export CERT_PATH=/etc/haproxy/

PS=$(ps -fA | grep hapi | grep -v grep | head -1)
echo $PS
RETVAL=0

start() {
  if [ -z "$PS" ]; then
    exec nohup /usr/local/bin/hapi >/var/log/hapi.api 2>&1 &
    RETVAL=1
  else
    echo "hapi was already running." 
  fi
}

stop() {
  pkill -9 hapi
}

status() {
  if [ -z "$PS" ]; then
    echo "hapi not running."
    RETVAL=1
  else
    echo "hapi running."
  fi
}

case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  status)
    status
    ;;
  restart)
    stop
    sleep 1
    start
    ;;
  *)
    echo $"Usage: hapi {start|stop|restart|status}"
    RETVAL=3
esac

exit $RETVAL
