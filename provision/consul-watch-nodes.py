#!/usr/bin/env python
import json, os, sys
from subprocess import PIPE, Popen

def log(data):
    print data
    p = Popen(args="echo '{}' >> /var/log/provisioning.log".format(data), stdout=PIPE, stderr=PIPE, shell=True)
    p.wait()

def source_vars(file):
    process = Popen(args="source {}; env".format(file), stdout=PIPE, stderr=PIPE, shell=True)
    for line in process.stdout:
        ( key, _, value ) = line.strip().partition("=")
        os.environ[key] = value
    process.wait()
    if process.returncode != 0:
        log( "[ERROR]: Could not source {}. Can't continue.".format( file ) )
        exit(100)

stdin_lines = list()
for line in sys.stdin:
    stdin_lines.append( line )

if len(stdin_lines) == 0:
    log( 'No data from consul.' )
else:
    
    base      = os.path.abspath(os.path.dirname(__file__))
    source_vars("{0}/vars".format(base))
    source_vars("{0}/env-setup.sh".format(base))

    complete_input = "".join( stdin_lines )
    parsed_input   = json.loads( complete_input )

    masters        = [ node for node in parsed_input if 'Node' in node and node['Node'].startswith("dcos_master_node") ]
    agents         = [ node for node in parsed_input if 'Node' in node and node['Node'].startswith("dcos_slave") ]

    if str(len(masters)) == os.environ['EXPECTED_MASTER_COUNT'] and str(len(agents)) == os.environ['EXPECTED_AGENT_COUNT']:

        log( 'Bootstrapping the node:' )
        process = Popen(args="cd {0} && ./bootstrap-machine-init.sh 2>&1".format(base), stdout=PIPE, stderr=PIPE, shell=True)
        for line in process.stdout:
            log( line.strip() )
        process.wait()
        if process.returncode != 0:
            log( "[ERROR]: bootstrap-machine-init.sh failed with exit code {}. Can't continue.".format( process.returncode ) )
            exit(101)

        log( 'Sourcing bootstrap variables:' )
        source_vars("{0}/bootstrap-vars".format(base))

        config = list()
        config.append("bootstrap_url: http://{}:{}".format(os.environ['IPV4_PRIVATE'], os.environ['BOOTSTRAP_PORT']))
        config.append("cluster_name: '{}'".format( os.environ['DATACENTER'] ))
        config.append("exhibitor_storage_backend: zookeeper")
        config.append("exhibitor_zk_hosts: {}:2181".format(os.environ['IPV4_PRIVATE']))
        config.append("exhibitor_zk_path: /dcos")
        config.append("master_discovery: static")
        config.append("master_list:")
        for master in masters:
            config.append("- {}".format( master['Address'] ))
        config.append("agent_list:")
        for agent in agents:
            config.append("- {}".format( agent['Address'] ))
        config.append("resolvers:")
        config.append("- 8.8.4.4")
        config.append("- 8.8.8.8")
        config.append("superuser_password_hash: '{}'".format(os.environ['SUPERUSER_PASSWORD']))
        config.append("superuser_username: '{}'".format(os.environ['SUPERUSER_USERNAME']))

        log( 'Writing bootstrap server configuration to file:' )
        with open("{}/genconf/config.yaml".format(base), "w") as cfg_file:
            cfg_file.write( "\n".join( config ) )

        log( 'Running final step of bootstrap:' )
        process = Popen(args="cd {0} && ./bootstrap-machine-ready.sh 2>&1".format(base), stdout=PIPE, stderr=PIPE, shell=True)
        for line in process.stdout:
            log( line.strip() )
        process.wait()
        if process.returncode != 0:
            log( "[ERROR]: bootstrap-machine-ready.sh failed with exit code {}. Can't continue.".format( process.returncode ) )
            exit(102)

        log( 'Yay - DONE \o/.' )

    else:

        log( 'Not enough machines:' )
        log( ' => masters: {} vs expected {}'.format( str(len(masters)), os.environ['EXPECTED_MASTER_COUNT'] ) )
        log( ' => agents:  {} vs expected {}'.format( str(len(agents)),  os.environ['EXPECTED_AGENT_COUNT'] ) )