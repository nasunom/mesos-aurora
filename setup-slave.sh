#!/bin/bash

export MY_HOST=$(ifconfig eth0|grep 'inet addr'|awk '{print $2}'|awk -F: '{print $2}')
export ZK_HOST=${ZK_HOST:-$MY_HOST}

# mesos resources (CPUs, Mem:MB, Disk:MB)
export MESOS_CPUS=${MESOS_CPUS:-30}
export MESOS_MEM=${MESOS_MEM:-65536}
export MESOS_DISK=${MESOS_DISK:-20480}

# docker-in-docker
/usr/local/bin/wrapdocker 2>/tmp/docker-daemon.log
docker version >/dev/null
if [ $? -ne 0 ];then
  sleep 10
  docker version >/dev/null || (echo "docker daemon failed to spawn."; exit 1)
fi

# mesos-slave
rm -rf /var/lib/mesos/*
exec /usr/sbin/mesos-slave --master=zk://$ZK_HOST:2181/mesos/master \
  --ip=$MY_HOST \
  --hostname=$MY_HOST \
  --attributes="host:$MY_HOST;rack:a" \
  --resources="cpus:$MESOS_CPUS;mem:$MESOS_MEM;disk:$MESOS_DISK" \
  --work_dir="/var/lib/mesos" \
  --containerizers=docker,mesos \
  >/tmp/mesos-slave-console.log 2>&1 &

# thermos-observer
export LD_LIBRARY_PATH=/usr/lib/jvm/java-7-openjdk-amd64/jre/lib/amd64/server
exec /aurora/dist/thermos_observer.pex \
  --root=/var/run/thermos \
  --port=1338 \
  --log_to_disk=NONE \
  --log_to_stderr=google:INFO \
  >/tmp/thermos_observer-console.log 2>&1 &
