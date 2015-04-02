#!/bin/bash

export MY_HOST=$(ifconfig eth0|grep 'inet addr'|awk '{print $2}'|awk -F: '{print $2}')
export ZK_HOST=${ZK_HOST:-$MY_HOST}

# zookeeper
export JVMFLAGS='-Djava.net.preferIPv4Stack=true'
rm -rf /var/lib/zookeeper/version-2 /var/lib/zookeeper/zookeeper_server.pid
hostname $MY_HOST
sed "1i $MY_HOST    $MY_HOST" /etc/hosts > /tmp/hosts; cp /tmp/hosts /etc/hosts
/usr/share/zookeeper/bin/zkServer.sh start

# mesos-master
export LD_LIBRARY_PATH=/usr/lib/jvm/java-7-openjdk-amd64/jre/lib/amd64/server
exec /usr/sbin/mesos-master \
  --zk=zk://$ZK_HOST:2181/mesos/master \
  --ip=$MY_HOST \
  --work_dir=/usr/local/aurora/master/db \
  --quorum=1 \
  >/tmp/mesos-master-console.log 2>&1 &

# aurora-scheduler
export LD_LIBRARY_PATH=/usr/lib/jvm/java-7-openjdk-amd64/jre/lib/amd64/server
export LIBPROCESS_IP=$ZK_HOST
export LIBPROCESS_PORT=8083
export AURORA_HOME=/usr/local/aurora
export DIST_DIR=/aurora/dist
export JAVA_OPTS='-Djava.library.path=/usr/lib -Dlog4j.configuration="file:///etc/zookeeper/conf/log4j.properties"'
export GLOG_v=0
export GLOBAL_CONTAINER_MOUNTS=${GLOBAL_CONTAINER_MOUNTS:-'/opt:/opt:rw'}
rm -rf /usr/local/aurora/master /usr/local/aurora/scheduler/*
mesos-log initialize --path=/usr/local/aurora/scheduler/db
exec $DIST_DIR/install/aurora-scheduler/bin/aurora-scheduler \
  -cluster_name=example \
  -http_port=8081 \
  -native_log_quorum_size=1 \
  -zk_endpoints=localhost:2181 \
  -mesos_master_address=zk://localhost:2181/mesos/master \
  -serverset_path=/aurora/scheduler \
  -native_log_zk_group_path=/aurora/replicated-log \
  -native_log_file_path=$AURORA_HOME/scheduler/db \
  -backup_dir=$AURORA_HOME/scheduler/backups \
  -thermos_executor_path=$DIST_DIR/thermos_executor.pex \
  -thermos_executor_flags="--announcer-enable --announcer-ensemble localhost:2181" \
  -gc_executor_path=$DIST_DIR/gc_executor.pex \
  -vlog=INFO \
  -logtostderr \
  -allowed_container_types=MESOS,DOCKER \
  -global_container_mounts=$GLOBAL_CONTAINER_MOUNTS \
  >/tmp/aurora_scheduler-console.log 2>&1 &
