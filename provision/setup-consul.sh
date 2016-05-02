#!/usr/bin/env bash
set -e

source `pwd`/env-setup.sh

log "Installing Consul dependencies..."

sudo yum update -y
sudo yum install -y unzip wget

base=`pwd`

mkdir -p /tmp/install-consul && cd /tmp/install-consul
sudo mkdir -p ${CONSUL_INSTALL_DIR}/data

if [ -z "$(consul 2>/dev/null)" ]; then
  log "Downloading Consul ${CONSUL_VERSION}..."
  CONSUL_ARCHIVE=consul_${CONSUL_VERSION}_linux_amd64.zip
  wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/${CONSUL_ARCHIVE}
  log "Installing Consul ${CONSUL_VERSION}..."
  unzip ${CONSUL_ARCHIVE} >/dev/null
  chmod +x consul
  sudo mv consul ${CONSUL_INSTALL_DIR}/consul
  sudo ln -s ${CONSUL_INSTALL_DIR}/consul /usr/bin/consul
else
  log "$(consul version | head -n 1) already installed."
fi

log "Setting up Consul service..."

sudo mkdir -p /etc/systemd/system/consul.d
sudo tee /etc/systemd/system/consul.service <<'EOF'
[Unit]
Description=consul agent
Requires=network-online.target
After=network-online.target

[Service]
EnvironmentFile=/etc/sysconfig/consul
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/bin/consul agent -config-dir=/etc/systemd/system/consul.d
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF

sudo touch /etc/sysconfig/consul
sudo chmod 0644 /etc/sysconfig/consul

BOOTSTRAP_EXPECT=0
if [ $IS_CONSUL_SERVER = true ]; then
  BOOTSTRAP_EXPECT=1
fi

sudo tee /etc/systemd/system/consul.d/consul.json <<EOF
{
  "node_name": "${NODE_NAME}",
  "rejoin_after_leave": true,
  "datacenter": "${DATACENTER}",
  "log_level": "INFO",
  "data_dir": "${CONSUL_INSTALL_DIR}/data",
  "server": ${IS_CONSUL_SERVER},
  "bootstrap_expect": ${BOOTSTRAP_EXPECT},
  "retry_join": [
    "${BOOTSTRAP_NODE_ADDRESS}"
  ],
  "addresses": {
    "dns": "127.0.0.1",
    "http": "${IPV4_PRIVATE}",
    "https": "${IPV4_PRIVATE}",
    "rpc": "127.0.0.1"
  },
  "ports": {
    "https": -1,
    "server": 8300,
    "serf_lan": 8301,
    "serf_wan": 8302,
    "rpc": 8400,
    "http": 8500,
    "dns": -1
  },
  "bind_addr": "${IPV4_PRIVATE}",
  "client_addr": "${IPV4_PRIVATE}",
  "leave_on_terminate": true
}
EOF

if [ $IS_BOOTSTRAP_SERVER = true ]; then
  sudo tee /etc/systemd/system/consul.d/watch-nodes.json <<EOF
{
  "watches": [{
    "type": "nodes",
    "handler": "${base}/consul-watch-nodes.py"
  }]
}
EOF
else
  sudo tee /etc/systemd/system/consul.d/watch-service-bootstrap-server.json <<EOF
{
  "watches": [{
    "type": "service",
    "service": "bootstrap-server",
    "handler": "${base}/consul-watch-bootstrap-server.py"
  }]
}
EOF
fi

sudo systemctl enable consul.service
sudo systemctl start consul

log "Consul ready."
