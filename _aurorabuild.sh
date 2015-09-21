#!/bin/bash -e

./pants binary src/main/python/apache/aurora/kerberos:kaurora_admin
cp dist/kaurora_admin.pex /usr/local/bin/aurora_admin

./pants binary src/main/python/apache/aurora/kerberos:kaurora
cp dist/kaurora.pex /usr/local/bin/aurora

./pants binary src/main/python/apache/aurora/executor:thermos_executor
./pants binary src/main/python/apache/thermos/runner:thermos_runner
build-support/embed_runner_in_executor.py
chmod +x dist/thermos_executor.pex
./pants binary src/main/python/apache/aurora/tools:thermos_observer
./pants binary src/main/python/apache/aurora/tools:thermos
cp dist/thermos.pex /usr/local/bin/thermos

# build Aurora Scheduler
CLASSPATH_PREFIX=dist/resources/main ./gradlew installDist
mkdir -p /var/db/aurora /var/lib/aurora/backups
