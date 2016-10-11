# DCOS terraform infrastructure

Sets up DCOS infrastructure on AWS.

## Install terraform

Download terraform for your operating system from [Terraform Download page](https://www.terraform.io/downloads.html).

For **OSX**, it will be:
```sh
OS_DIST=darwin
```
For **Linux**
```sh
OS_DIST=linux
```

Now, assuming you're on a amd64 arch, you can install by running the following:

```sh
    cd $HOME
    TF_VERSION=0.6.14
    wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_${OS_DIST}_amd64.zip
    unzip terraform_${TF_VERSION}_${OS_DIST}_amd64.zip
    ln -s $HOME/terraform_${TF_VERSION}_${OS_DIST}_amd64 /usr/local/terraform
    export PATH=/usr/local/terraform:$PATH
```


## Get this project

    mkdir -p $HOME/dcos-up
    cd $HOME/dcos-up
    git clone https://github.com/ant3dr/dcos-up.git .

## Create terraform credentials file

    mkdir -p $HOME/.aws
    cat > $HOME/.aws/terraform <<EOF
    #!/bin/bash
    export AWS_ACCESS_KEY_ID=AKIA...
    export AWS_SECRET_ACCESS_KEY=...
    export AWS_DEFAULT_REGION="us-east-1"
    EOF

## See the plan

    cd $HOME/dcos-up
    source $HOME/.aws/terraform
    terraform plan

## Create infrastructure

    cd $HOME/dcos-up
    source $HOME/.aws/terraform
    terraform apply

This will create all AWS resources and start the process of setting up DCOS masters, agents and the bootstrap node.
TODO: ... add estimates on how long does it usually take to create the infra.

## Infrastructure name

The template defines infrastructure name using the `infra_name` variable. The default name is `test_infra`, to change the name, for any Terraform operation:

    cd $HOME/dcos-terraform
    source $HOME/.aws/terraform
    TF_VAR_infra_name=myinfra
    terraform apply
    ...

## How does this work

The `terraform apply` command makes sure that all machines come up on the cloud provider and that all of them are set up for DCOS + have `consul` installed.
From here, consul takes over. The `consul-watch-nodes.py` watcher awaits for all master and agent nodes. Once these are up, the watcher triggers the bootstrap node `bootstrap` process: https://docs.mesosphere.com/concepts/installing/installing-enterprise-edition/manual-installation/.
When the bootstrap process finishes, the bootstrap node has the bootstrap docker container running. This container is what master and agents use to download `dcos_install.sh` program. The final step on the bootstrap node is registering bootstrap container service.  
This service is then detected by the `consul-service-watch.py`, this watch triggers `setup-dcos-node.sh` run on master and agent nodes.  
Once `setup-dcos-node.sh` finishes on all nodes, DCOS installation is complete.

## Operating system

This setup uses CoreOS . AMI IDs:

- US East (N. Virginia): `ami-1c94e10b`
- US West (N. California): `ami-43561a23`

# License

Copyright 2016 Data Fellas SPRL

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

