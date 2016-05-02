#!/usr/bin/env bash

source `pwd`/env-setup.sh

if [ -f /etc/dcos-setup-done ]; then
  log "DCOS ${DCOS_NODE_TYPE} already set up."
else
  log "Setting up DCOS ${DCOS_NODE_TYPE}..."
  curl -O http://${BOOTSTRAP_NODE_ADDRESS}:${BOOTSTRAP_PORT}/dcos_install.sh
  if [ "${DCOS_NODE_TYPE}" = "master" ]; then

    bash ./dcos_install.sh ${DCOS_NODE_TYPE}

    dcos_version=`cat /opt/mesosphere/etc/dcos-version.json | /usr/bin/jq '.version' -r`
    log "DCOS version $dcos_version."
    if [[ $dcos_version == 1.6* ]]; then

      ## Apparently in 1.6 there's a bug which requires restarting dcos-cosmos service.
      ## So we do.
      ## It is fixed in 1.7.

      log "Attempting fixing the problem with the dcos-cosmos service..."
      log "Setting up dcos-cli..."

      mkdir -p dcos-cli && pushd dcos-cli >/dev/null
      curl -O https://downloads.mesosphere.com/dcos-cli/install.sh

      code=-1
      log "Attempting installing dcos-cli..."
      while [ "$code" != "0" ]; do
        echo no | bash install.sh . http://${IPV4_PRIVATE}
        code=$?
        if [ $code = 0 ]; then
          log "dcos-cli installed."
        else
          log "dcos-cli not installed yet, waiting for dcos to come up..."
          /bin/sleep 2
        fi
      done

      log "dcos-cli installed. Performing test package installation..."

      echo yes | ./bin/dcos package install marathon
      if [ $? = 0 ]; then
        # Oh, it succeeded? So we need to uninstall the package...
        log "dcos package install actually worked. Tidying up after myself."
        ./bin/dcos package uninstall marathon
      else
        log "dcos package install failed. Restarting dcos-cosmos service."
        systemctl restart dcos-cosmos
        log "dcos should be now fine for package install commands."
      fi

      popd >/dev/null
    fi

  elif [ "${DCOS_NODE_TYPE}" = "slave" ]; then
    bash ./dcos_install.sh ${DCOS_NODE_TYPE}
  elif [ "${DCOS_NODE_TYPE}" = "slave_public" ]; then
    bash ./dcos_install.sh ${DCOS_NODE_TYPE}
  else
    log "Unsupported DCOS_NODE_TYPE ${DCOS_NODE_TYPE}"
  fi
  tee `date` >> /etc/dcos-setup-done
  log " => DONE"
fi