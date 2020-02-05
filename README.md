 # Ansible playbook and roles to create a CentOs Docker Swarm Cluster on AWS/EC2

[![CI](https://travis-ci.com/vittorio-nardone/ansible-swarm-cluster.svg?branch=master)](https://travis-ci.com/vittorio-nardone/ansible-swarm-cluster)


 ## Description
 This Ansible playbook creates a Docker Swarm Cluster on AWS/EC2 with CentOs.  
 These roles are defined:
 - `aws_ec2_group` 
   Deploy a group of ec2 instances (exact count on "group" tag) 
   and store instances in ansible in memory inventory (default group is *aws_ec2*)
  
 - `aws_ec2_custom_ebs_size`
   Resize first ec2 attached ebs volume to a custom size. 
   Resizing is performed on a filtered list of ec2 instances (*ec2_selection_filter*)

 - `aws_ec2_custom_sg`
   Set / Update an ec2 security group with specified rules (*sec_group_rules*)

 - `aws_ec2_swarm_nodes_definition`
   Get a group of ec2 instances (*ec2_selection_filter*), check tags (*swarm_role*) and build 
   a list of deployed swarm nodes. 
   Tag unassigned ec2 instances with correct swarm role: 
     - if managers list is empty, first unassigned ec2 instance is tagged as *manager*
     - if manager is present, other unassigned ec2 instances are tagged as *worker* 
   Store swarm manager instances in ansible in memory inventory with group *swarm_managers*
   Store swarm worker instances in ansible in memory inventory with group *swarm_workers* 

 - `docker`
   A generic Docker installation role

 - `docker_tls`
   Docker TLS configuration to only accept connections from clients 
   providing a certificate trusted by our CA

 - `swarm_managers`
   Check if swarm cluster is already active and, if required, initialized it.
   Manager and Worker join-tokens are stored in ansible in-memory inventory in manager
   instance details  

 - `swarm_workers`
   Check if docker node is already configured as swarm worker and, if required, configure it to
   join specified cluster (swarm_manager_ip / swarm_join_token)   

## Setup & Run

If you need to install Ansible and dependencies, a generic way is:

    sudo apt install python
    sudo apt install python-pip
    pip install boto boto3 ansible

To run this playbook you need:
- a valid AWS Access Key & Secret Key. 
- a key pair to ssh-login to deployed EC2 instances

To create a AWS access keys, follow these [steps](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html#id_users_create_console).
To store your AWS access keys create a vault:

    mkdir -p group_vars/all/
    ansible-vault create group_vars/all/pass.yml 

and store information in vault file:

    aws_access_key_id: <your access key>
    aws_secret_access_key: <your secret access key>

To generate EC2 ssh-login key pair use:

    ssh-keygen -t rsa -b 4096 -f ec2_key

Finally, to run playbook use:

    ansible-playbook playbook.yml --ask-vault-pass --tags deploy

## Use deployed Docker Swarm cluster

Playbook creates the file `cluster-manager.host` to store Swarm manager public hostname and folder `docker_certs` to store TLS certificates.

To set your docker client environment use:

    export DOCKER_MANAGER_HOST=$(cat cluster-manager.host)
    export DOCKER_TLS_VERIFY=1
    export DOCKER_HOST=$DOCKER_MANAGER_HOST:2376
    export DOCKER_CERT_PATH=docker_certs/$DOCKER_MANAGER_HOST/

After that, you can list docker nodes using:

    docker service node ls

To deploy a service to your cluster use:

    docker service create --replicas 2 nginx

## Network Security

A Security Group is created and assigned to nodes. 
Rules allow: 
- incoming SSH (22) from public internet
- incoming Docker client connections (2376) - TLS required - from public internet
- incoming Docker Swarm connections (2377) from same security group only   

Docker Swarm cluster is configured to use private IPs.

## Notes

- Scale-out is correctly supported by playbook. If `instance_count` is incremented, new EC2 docker nodes are deployed and joined to Swarm cluster as workers.
- Scale-in is not supported by this playbook.

## CI Pipeline

Travis CI is configured to perform build tests at every code push to repository:
- code linting, using `ansible-lint`
- `docker` role, using `molecule` to check if `docker-ce` package is successfully installed 

