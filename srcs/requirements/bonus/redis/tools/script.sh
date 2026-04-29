#!/bin/bash
set -uo pipefail
exec redis-server /etc/redis/redis.conf
