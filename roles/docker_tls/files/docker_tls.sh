#!/bin/bash
# This script will help you setup Docker for TLS authentication.
# Run it passing in the arguement for the FQDN of your docker server
#
# For example:
#    ./create-docker-tls.sh myhost.docker.com
# 
# The script will also create a profile.d (if it exists) entry 
# which configures your docker client to use TLS
#
# We will also overwrite /etc/sysconfig/docker (again, if it exists) to configure the daemon.  
# A backup will be created at /etc/sysconfig/docker.unixTimestamp
#
# MIT License applies to this script.  I don't accept any responsibility for 
# damage you may cause using it.
#

set -e
STR=2048
if [ "$#" -gt 0 ]; then
  DOCKER_HOST="$1"
else
  echo " => ERROR: You must specify the docker FQDN as the first arguement to this scripts! <="
  exit 1
fi

if [ "$USER" == "root" ]; then
  echo " => WARNING: You're running this script as root, therefore root will be configured to talk to docker"
  echo " => If you want to have other users query docker too, you'll need to symlink /root/.docker to /theuser/.docker"
fi

echo " => Using Hostname: $DOCKER_HOST  You MUST connect to docker using this host!"

echo " => Ensuring config directory exists..."
mkdir -p "$HOME/.docker"
cd $HOME/.docker

echo " => Verifying ca.srl"
if [ ! -f "ca.srl" ]; then
  echo " => Creating ca.srl"
  echo 01 > ca.srl
else
  exit 0
fi

echo " => Generating CA key"
openssl genrsa \
  -out ca-key.pem $STR

echo " => Generating CA certificate"
openssl req \
  -new \
  -key ca-key.pem \
  -x509 \
  -days 3650 \
  -nodes \
  -subj "/CN=$HOSTNAME" \
  -out ca.pem

echo " => Generating server key"
openssl genrsa \
  -out server-key.pem $STR

echo " => Generating server CSR"
openssl req \
  -subj "/CN=$DOCKER_HOST" \
  -new \
  -key server-key.pem \
  -out server.csr

echo " => Signing server CSR with CA"
openssl x509 \
  -req \
  -days 3650 \
  -in server.csr \
  -CA ca.pem \
  -CAkey ca-key.pem \
  -out server-cert.pem

echo " => Generating client key"
openssl genrsa \
  -out key.pem $STR

echo " => Generating client CSR"
openssl req \
  -subj "/CN=docker.client" \
  -new \
  -key key.pem \
  -out client.csr

echo " => Creating extended key usage"
echo extendedKeyUsage = clientAuth > extfile.cnf

echo " => Signing client CSR with CA"
openssl x509 \
  -req \
  -days 3650 \
  -in client.csr \
  -CA ca.pem \
  -CAkey ca-key.pem \
  -out cert.pem \
  -extfile extfile.cnf

if [ -d "/etc/profile.d" ]; then
  echo " => Creating profile.d/docker"
  sudo sh -c "echo '#!/bin/bash 
export DOCKER_CERT_PATH=/home/$USER/.docker
export DOCKER_HOST=tcp://$DOCKER_HOST:2376
export DOCKER_TLS_VERIFY=1' > /etc/profile.d/docker.sh"
  sudo chmod +x /etc/profile.d/docker.sh
  source /etc/profile.d/docker.sh
else
  echo " => WARNING: No /etc/profile.d directoy on your system."
  echo " =>   You will need to set the following environment variables before running the docker client:"
  echo " =>   DOCKER_HOST=tcp://$DOCKER_HOST:2376"
  echo " =>   DOCKER_TLS_VERIFY=1"
fi

OPTIONS="--tlsverify --tlscacert=$HOME/.docker/ca.pem --tlscert=$HOME/.docker/server-cert.pem --tlskey=$HOME/.docker/server-key.pem -H=0.0.0.0:2376"
if [ -f "/etc/sysconfig/docker" ]; then
  echo " => Configuring /etc/sysconfig/docker"
  BACKUP="/etc/sysconfig/docker.$(date +"%s")"
  sudo mv /etc/sysconfig/docker $BACKUP
  sudo sh -c "echo '# The following line was added by ./create-certs docker TLS configuration script
OPTIONS=\"$OPTIONS\"
# A backup of the old file is at $BACKUP.' >> /etc/sysconfig/docker"
  echo " => Backup file location: $BACKUP"
else
  echo " => WARNING: No /etc/sysconfig/docker file found on your system."
  echo " =>   You will need to configure your docker daemon with the following options:"
  echo " =>   $OPTIONS" 
fi

export DOCKER_HOST=tcp://DOCKER_HOST:2376
export DOCKER_TLS_VERIFY=1
echo " => Done! You just need to restart docker for the changes to take effect"