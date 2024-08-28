#!/bin/bash
cat /etc/exports
trap "stop; exit 0;" SIGTERM SIGINT

stop()
{
  echo "SIGTERM caught, terminating NFS process(es)..."
  /usr/sbin/exportfs -uav
  /usr/sbin/rpc.nfsd 0
  pid1=`pidof rpc.nfsd`
  pid2=`pidof rpc.mountd`
  pid3=`pidof rpcbind`
  kill -TERM $pid1 $pid2 $pid3 > /dev/null 2>&1
  echo "Terminated."
  exit
}

set -uo pipefail

echo "Displaying /etc/exports contents:"
cat /etc/exports
echo ""

echo "Starting rpcbind..."
/sbin/rpcbind -w
echo "Displaying rpcbind status..."
/sbin/rpcinfo

echo "Starting NFS in the background..."
/usr/sbin/rpc.nfsd --debug 8 --no-udp
echo "Exporting File System..."
if /usr/sbin/exportfs -rv; then
    /usr/sbin/exportfs
else
    echo "Export validation failed, exiting..."
    exit 1
fi
echo "Starting Mountd..."
/usr/sbin/rpc.mountd --debug all --no-udp -F

sleep 1
exit 1