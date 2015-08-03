#!/bin/bash -e

./pants binary src/main/python/apache/aurora/admin:kaurora_admin
cp dist/kaurora_admin.pex /usr/local/bin/aurora_admin

./pants binary src/main/python/apache/aurora/client/cli:kaurora
cp dist/kaurora.pex /usr/local/bin/aurora

./pants binary src/main/python/apache/aurora/executor/bin:thermos_executor
./pants binary src/main/python/apache/thermos/bin:thermos_runner
build-support/embed_runner_in_executor.py
chmod +x dist/thermos_executor.pex
./pants binary src/main/python/apache/aurora/tools:thermos_observer

# build Aurora Scheduler
./gradlew installDist
mkdir -p /var/db/aurora /var/lib/aurora/backups
