#!/usr/bin/env bash

sudo touch /var/log/provisioning.log
sudo chmod 0666 /var/log/provisioning.log

if [ -f `pwd`/vars ]; then
  source `pwd`/vars
fi

log() {
  echo "[`date +%s`]: $1"
  echo "[`date +%s`]: $1" >> /var/log/provisioning.log
}

export CONSUL_VERSION=${CONSUL_VERSION-0.6.4}
export CONSUL_INSTALL_DIR=${CONSUL_INSTALL_DIR-"/opt/consul"}
export IS_CONSUL_SERVER=${IS_CONSUL_SERVER-false}
export IS_BOOTSTRAP_SERVER=${IS_BOOTSTRAP_SERVER-false}
export EXPECTED_MASTER_COUNT=${EXPECTED_MASTER_COUNT-0}
export EXPECTED_AGENT_COUNT=${EXPECTED_AGENT_COUNT-0}