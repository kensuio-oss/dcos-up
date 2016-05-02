#!/usr/bin/env bash

## NO set -e, handle errors manually here

source `pwd`/env-setup.sh

export SUPERUSER_PASSWORD=${SUPERUSER_PASSWORD-"superuser-pass"}
export DCOS_ZK_NAME=${DCOS_ZK_NAME-dcos_int_zk}

# Create any directory we may require:
log "Ensuring directories..."
mkdir -p /var/zookeeper/dcos
mkdir -p genconf

# Pull docker images, start zookeeper:

log "Pulling nginx docker image..."
docker pull nginx
log "Pulling jplock/zookeeper docker image..."
docker pull jplock/zookeeper

if [ -z "$(docker ps | grep dcos_int_zk 2>/dev/null)" ]; then
  log "Starting zookeeper container..."
  docker run -d -p 2181:2181 -p 2888:2888 -p 3888:3888 -v /var/zookeeper/dcos:/tmp/zookeeper --name=$DCOS_ZK_NAME jplock/zookeeper
  if [ $? != 0 ]; then
    log "[ERROR]: Could not start zookeeper container ${DCOS_ZK_NAME}."
    exit 200
  fi
else
  log "Zookeeper container already up..."
fi
# Get zookeeper IP address:
export DCOS_ZK_IP=$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $DCOS_ZK_NAME | tr -d '\n')
if [ $? != 0 ]; then
  log "[ERROR]: Could not read zookeeper container ${DCOS_ZK_NAME} IP address."
  exit 201
fi
log "DCOS Zookeeper IP address: ${DCOS_ZK_IP}"

# Pull docs config generator:
if [ ! -f dcos_generate_config.sh.downloaded ]; then
  log "Downloading dcos_generate_config.sh file..."
  #wget https://downloads.mesosphere.com/dcos/stable/dcos_generate_config.sh -O dcos_generate_config.sh
  wget https://downloads.dcos.io/dcos/EarlyAccess/dcos_generate_config.sh -O dcos_generate_config.sh
  if [ $? != 0 ]; then
    log "[ERROR]: Could not download dcos_generate_config.sh file."
    exit 202
  else
    log `date` > dcos_generate_config.sh.downloaded
  fi
else
  log "dcos_generate_config.sh file already exists."
fi

# IP detection scripts:
log "Generating ip-detect programs..."
cat > genconf/ip-detect <<EOF
#!/bin/sh
curl -fsSL http://169.254.169.254/latest/meta-data/local-ipv4
EOF
cat > genconf/ip-detect-public <<EOF
#!/bin/sh
curl -fsSL http://169.254.169.254/latest/meta-data/public-ipv4
EOF

# Make programs executable:
chmod +x dcos_generate_config.sh
chmod +x genconf/ip-detect
chmod +x genconf/ip-detect-public

log "Generating run_dcos_gen.sh program..."
cat > run_dcos_gen.py <<EOF
import subprocess
pass_file = "/etc/dcos-hashed-password"
p = subprocess.Popen("./dcos_generate_config.sh --hash-password ${SUPERUSER_PASSWORD} 2>&1", stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
p.wait()
for line in p.stdout.read().split("\n"):
    if line.startswith("$"):
        f = open(pass_file,'w')
        f.write( line.split("=")[1] )
        f.close()
        print "Hashed dcos password saved in {}".format(pass_file)
if p.returncode != 0:
  exit(100)
EOF

log "Running run_dcos_gen.py program..."
python run_dcos_gen.py 2>&1 >> /var/log/provisioning.log

if [ $? != 0 ]; then
  log "[ERROR]: python run_dcos_gen.py failed."
  exit 203
fi

log "Generating bootstrap configuration variables..."
echo export DCOS_ZK_IP=${DCOS_ZK_IP} > `pwd`/bootstrap-vars
echo export SUPERUSER_PASSWORD=$(cat /etc/dcos-hashed-password | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g") >> `pwd`/bootstrap-vars
echo export SUPERUSER_USERNAME=$(whoami) >> `pwd`/bootstrap-vars
