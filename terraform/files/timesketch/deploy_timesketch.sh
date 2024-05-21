#!/bin/bash
# Copyright 2020 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

START_CONTAINER=

if [ "$1" == "--start-container" ]; then
    START_CONTAINER=yes
fi

# Exit early if run as non-root user.
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script need to run as root."
  exit 1
fi

# Exit early if a timesketch directory already exists.
if [ -d "./timesketch" ]; then
  echo "ERROR: Timesketch directory already exist."
  exit 1
fi

# Exit early if docker is not installed.
if ! command -v docker; then
  echo "ERROR: Docker is not available."
  echo "See: https://docs.docker.com/engine/install/ubuntu/"
  exit 1
fi

# Exit early if docker compose is not installed.
if ! docker compose &>/dev/null; then
  echo "ERROR: docker-compose-plugin is not installed."
  exit 1
fi

# Exit early if there are Timesketch containers already running.
if [ ! -z "$(docker ps | grep timesketch)" ]; then
  echo "ERROR: Timesketch containers already running."
  exit 1
fi

# Tweak for OpenSearch
echo "* Setting vm.max_map_count for Elasticsearch"
sysctl -q -w vm.max_map_count=262144
if [ -z "$(grep vm.max_map_count /etc/sysctl.conf)" ]; then
  echo "vm.max_map_count=262144" >> /etc/sysctl.conf
fi

# Create dirs
mkdir -p timesketch/{data/postgresql,data/opensearch,logs,etc,etc/timesketch,etc/timesketch/sigma/rules,upload}
# TODO: Switch to named volumes instead of host volumes.
chown 1000 timesketch/data/opensearch

echo -n "* Setting default config parameters.."
POSTGRES_USER="timesketch"
POSTGRES_PASSWORD="$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 32 ; echo)"
POSTGRES_ADDRESS="postgres"
POSTGRES_PORT=5432
SECRET_KEY="$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 32 ; echo)"
OPENSEARCH_ADDRESS="opensearch"
OPENSEARCH_PORT=9200
OPENSEARCH_MEM_USE_GB=$(cat /proc/meminfo | grep MemTotal | awk '{printf "%.0f", ($2 / (1024 * 1024) / 2)}')
REDIS_ADDRESS="redis"
REDIS_PORT=6379
GITHUB_BASE_URL="https://raw.githubusercontent.com/google/timesketch/master"
echo "OK"
echo "* Setting OpenSearch memory allocation to ${OPENSEARCH_MEM_USE_GB}GB"

# Docker compose and configuration
echo -n "* Fetching configuration files.."
curl -s $GITHUB_BASE_URL/docker/release/docker-compose.yml > timesketch/docker-compose.yml
curl -s $GITHUB_BASE_URL/docker/release/config.env > timesketch/config.env

# Fetch default Timesketch config files
curl -s $GITHUB_BASE_URL/data/timesketch.conf > timesketch/etc/timesketch/timesketch.conf
curl -s $GITHUB_BASE_URL/data/tags.yaml > timesketch/etc/timesketch/tags.yaml
curl -s $GITHUB_BASE_URL/data/plaso.mappings > timesketch/etc/timesketch/plaso.mappings
curl -s $GITHUB_BASE_URL/data/generic.mappings > timesketch/etc/timesketch/generic.mappings
curl -s $GITHUB_BASE_URL/data/regex_features.yaml > timesketch/etc/timesketch/regex_features.yaml
curl -s $GITHUB_BASE_URL/data/winevt_features.yaml > timesketch/etc/timesketch/winevt_features.yaml
curl -s $GITHUB_BASE_URL/data/ontology.yaml > timesketch/etc/timesketch/ontology.yaml
curl -s $GITHUB_BASE_URL/data/intelligence_tag_metadata.yaml > timesketch/etc/timesketch/intelligence_tag_metadata.yaml
curl -s $GITHUB_BASE_URL/data/sigma_config.yaml > timesketch/etc/timesketch/sigma_config.yaml
curl -s $GITHUB_BASE_URL/data/sigma/rules/lnx_susp_zmap.yml > timesketch/etc/timesketch/sigma/rules/lnx_susp_zmap.yml
curl -s $GITHUB_BASE_URL/data/plaso_formatters.yaml > timesketch/etc/timesketch/plaso_formatters.yaml
curl -s $GITHUB_BASE_URL/data/context_links.yaml > timesketch/etc/timesketch/context_links.yaml
curl -s $GITHUB_BASE_URL/contrib/nginx.conf > timesketch/etc/nginx.conf
echo "OK"

# Create a minimal Timesketch config
echo -n "* Edit configuration files.."
sed -i 's#SECRET_KEY = \x27\x3CKEY_GOES_HERE\x3E\x27#SECRET_KEY = \x27'$SECRET_KEY'\x27#' timesketch/etc/timesketch/timesketch.conf

# Set up the Elastic connection
sed -i 's#^OPENSEARCH_HOST = \x27127.0.0.1\x27#OPENSEARCH_HOST = \x27'$OPENSEARCH_ADDRESS'\x27#' timesketch/etc/timesketch/timesketch.conf
sed -i 's#^OPENSEARCH_PORT = 9200#OPENSEARCH_PORT = '$OPENSEARCH_PORT'#' timesketch/etc/timesketch/timesketch.conf

# Set up the Redis connection
sed -i 's#^UPLOAD_ENABLED = False#UPLOAD_ENABLED = True#' timesketch/etc/timesketch/timesketch.conf
sed -i 's#^UPLOAD_FOLDER = \x27/tmp\x27#UPLOAD_FOLDER = \x27/usr/share/timesketch/upload\x27#' timesketch/etc/timesketch/timesketch.conf

sed -i 's#^CELERY_BROKER_URL =.*#CELERY_BROKER_URL = \x27redis://'$REDIS_ADDRESS':'$REDIS_PORT'\x27#' timesketch/etc/timesketch/timesketch.conf
sed -i 's#^CELERY_RESULT_BACKEND =.*#CELERY_RESULT_BACKEND = \x27redis://'$REDIS_ADDRESS':'$REDIS_PORT'\x27#' timesketch/etc/timesketch/timesketch.conf

# Set up the Postgres connection
sed -i 's#postgresql://<USERNAME>:<PASSWORD>@localhost#postgresql://'$POSTGRES_USER':'$POSTGRES_PASSWORD'@'$POSTGRES_ADDRESS':'$POSTGRES_PORT'#' timesketch/etc/timesketch/timesketch.conf

sed -i 's#^POSTGRES_PASSWORD=#POSTGRES_PASSWORD='$POSTGRES_PASSWORD'#' timesketch/config.env
sed -i 's#^OPENSEARCH_MEM_USE_GB=#OPENSEARCH_MEM_USE_GB='$OPENSEARCH_MEM_USE_GB'#' timesketch/config.env

ln -s ./config.env ./timesketch/.env
echo "OK"
echo "* Installation done."
