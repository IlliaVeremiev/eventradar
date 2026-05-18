#!/bin/bash
set -euo pipefail
echo "Waiting for MySQL to be healthy..."
RETRIES=60
until [ "$(docker inspect --format='{{.State.Health.Status}}' mysql 2>/dev/null)" = "healthy" ]; do
  RETRIES=$((RETRIES - 1))
  if [ "$RETRIES" -le 0 ]; then
    echo "ERROR: MySQL did not become healthy in time."
    docker logs mysql --tail 30
    exit 1
  fi
  sleep 3
done
echo "MySQL is healthy."
