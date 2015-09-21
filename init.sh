#!/bin/bash

setup_master() {
  # zookeeper
  rm -rf /var/lib/zookeeper/version-2
  service zookeeper start

  # mesos-master
  export LD_LIBRARY_PATH=/usr/lib/jvm/java-7-openjdk-amd64/jre/lib/amd64/server
  exec /usr/sbin/mesos-master \
    --zk=zk://$ZK_HOST:2181/mesos/master \
    --ip=$MY_HOST \
    --work_dir=/usr/local/aurora/master/db \
    --quorum=1 \
    >/tmp/mesos.log 2>&1 &

  rm -rf /usr/local/aurora/master /var/db/aurora/*
  mesos-log initialize --path="/var/db/aurora"

  # aurora-scheduler
  export GLOG_v=0
  export LIBPROCESS_PORT=8083
  export LIBPROCESS_IP=$ZK_HOST
  export DIST_DIR=/aurora/dist
  export JAVA_OPTS='-Djava.library.path=/usr/lib -Dlog4j.configuration="file:///etc/zookeeper/conf/log4j.properties" -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5005'
  export GLOBAL_CONTAINER_MOUNTS=${GLOBAL_CONTAINER_MOUNTS:-'/opt:/opt:rw'}

  cd $DIST_DIR/install/aurora-scheduler
  exec ./bin/aurora-scheduler \
    -cluster_name=devcluster \
    -hostname=$MY_HOST \
    -http_port=8081 \
    -native_log_quorum_size=1 \
    -zk_endpoints=localhost:2181 \
    -mesos_master_address=zk://localhost:2181/mesos/master \
    -serverset_path=/aurora/scheduler \
    -native_log_zk_group_path=/aurora/replicated-log \
    -native_log_file_path=/var/db/aurora \
    -backup_dir=/var/lib/aurora/backups \
    -thermos_executor_path=$DIST_DIR/thermos_executor.pex \
    -thermos_executor_flags="--announcer-enable --announcer-ensemble localhost:2181" \
    -vlog=INFO \
    -logtostderr \
    -allowed_container_types=MESOS,DOCKER \
    -global_container_mounts=$GLOBAL_CONTAINER_MOUNTS \
    -use_beta_db_task_store=true \
    -enable_h2_console=true \
    -tier_config=/aurora/src/test/resources/org/apache/aurora/scheduler/tiers-example.json \
    -receive_revocable_resources=true \
    >/tmp/aurora_scheduler-console.log 2>&1 &
}

setup_slave() {
  # mesos resources (CPUs, Mem:MB, Disk:MB)
  export MESOS_CPUS=${MESOS_CPUS:-33}
  export MESOS_MEM=${MESOS_MEM:-90000}
  export MESOS_DISK=${MESOS_DISK:-100000}

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
    >/tmp/mesos.log 2>&1 &

  # thermos-observer
  exec /aurora/dist/thermos_observer.pex \
    --root=/var/run/thermos \
    --port=1338 \
    --log_to_disk=NONE \
    --log_to_stderr=google:INFO \
    >/tmp/thermos_observer-console.log 2>&1 &
}

####

export MY_HOST_IF=${MY_HOST_IF:-eth0}
export MY_HOST=$(ifconfig $MY_HOST_IF|grep 'inet addr'|awk '{print $2}'|awk -F: '{print $2}')
export ZK_HOST=${ZK_HOST:-$MY_HOST}
hostname $MY_HOST
sed "1i $MY_HOST    $MY_HOST" /etc/hosts > /tmp/hosts; cp /tmp/hosts /etc/hosts

unset MESOS_VERSION

if [ "$ZK_HOST" != "$MY_HOST" ]; then
  echo "setup mesos-slave"
  setup_slave
else
  echo "setup mesos-master"
  setup_master
fi

#/usr/sbin/sshd -D
tail -f /tmp/mesos.log

