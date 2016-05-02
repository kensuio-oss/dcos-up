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

stdin_lines = list()
for line in sys.stdin:
    stdin_lines.append( line )

if len(stdin_lines) == 0:
    log( 'No data from consul.' )
else:
    
    base           = os.path.abspath(os.path.dirname(__file__))
    complete_input = "".join( stdin_lines )
    parsed_input   = json.loads( complete_input )

    if len(parsed_input) == 0:
        log( "No bootstrap service avilable." )
    else:
        bootstrap_server = parsed_input[0]
        log( "Bootstrap server available: {} @ {}:{}".format(
                    bootstrap_server['Node']['Node'],
                    bootstrap_server['Service']['Address'],
                    bootstrap_server['Service']['Port'] ) )

        log( 'Installing DCOS:' )

        process = Popen(args="cd {0} && ./setup-dcos-node.sh 2>&1".format(base), stdout=PIPE, stderr=PIPE, shell=True)
        for line in process.stdout:
            log( line.strip() )
        process.wait()
        if process.returncode != 0:
            log( "[ERROR]: setup-dcos-node.sh failed with exit code {}.".format( process.returncode ) )
            exit(100)