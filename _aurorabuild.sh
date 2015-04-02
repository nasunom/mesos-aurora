#!/bin/bash -e

./pants binary src/main/python/apache/aurora/admin:aurora_admin
cp dist/aurora_admin.pex /usr/local/bin/aurora_admin

./pants binary src/main/python/apache/aurora/client/cli:aurora
cp dist/aurora.pex /usr/local/bin/aurora

./pants binary src/main/python/apache/aurora/executor/bin:gc_executor
./pants binary src/main/python/apache/aurora/executor/bin:thermos_executor
./pants binary src/main/python/apache/thermos/bin:thermos_runner
./pants binary src/main/python/apache/thermos/observer/bin:thermos_observer

# Package runner within executor.
python <<EOF
import contextlib
import zipfile
with contextlib.closing(zipfile.ZipFile('dist/thermos_executor.pex', 'a')) as zf:
  zf.writestr('apache/aurora/executor/resources/__init__.py', '')
  zf.write('dist/thermos_runner.pex', 'apache/aurora/executor/resources/thermos_runner.pex')
EOF

# build Aurora Scheduler
./gradlew installApp
mkdir -p /usr/local/aurora/scheduler

