#!/bin/bash

usage() { echo "Usage: $0 [-m master|worker|all] [-v v1.21.6+rke2r1] [-s 192.168.1.100] [-t K1075c2da4946626e73...] " 1>&2; exit 1; }

while getopts ":m:v:s:t:" o; do
    case "${o}" in
        m)
            m=${OPTARG}
            ((m == master || m == worker || m == all)) || usage
            ;;
        v)
            v=${OPTARG}
            ;;
        s)
            s=${OPTARG}
            ;;
        t)
            t=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${m}" ];
then
  echo "The mode flag is required"
  echo "master: Installs RKE2 Server with CriticalAddonsOnly taint"
  echo "all: Installs RKE2 Server with worker role"
  echo "worker: Installs RKE2 Agent and joins the node as a worker node"
  usage
fi

if [ -z "${v}" ];
then
  INSTALL_RKE2_VERSION_FLAG=""
else
  INSTALL_RKE2_VERSION_FLAG=`echo "INSTALL_RKE2_VERSION=${v}"`
fi

if [[ "${m}" ==  "master" ]] || [[ "${m}" ==  "all" ]]
then
  echo "Installing RKE2 Server...."
  curl -sfL https://get.rke2.io | `echo $INSTALL_RKE2_VERSION_FLAG` sh -
  echo "Setting up RKE2 Server service..."
  systemctl enable rke2-server.service
else
  echo "Installing RKE2 agent...."
  curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" `echo $INSTALL_RKE2_VERSION_FLAG` sh -
  echo "Setting up RKE2 agent service..."
  systemctl enable rke2-agent.service
fi

echo "Collecting IPs..."
privateip=`hostname -i | awk '{print $1}'`
echo "Private IP: $privateip"
if [[ -z $privateip ]]
then
  echo "No private IP detected"
  exit 2
fi
publicip=`curl -s ifconfig.me.`
echo "Public IP: $publicip"
if [[ -z $publicip ]]
then
  echo "No public IP detected"
  exit 2
fi

echo "Creating RKE2 config..."
mkdir -p /etc/rancher/rke2/
rm -f /etc/rancher/rke2/config.yaml

if [[ -z "${s}" ]]
then
  echo "No server is set, RKE2 will bootstrap a new cluster"
else
  echo "Joining an existing RKE2 cluster"
  echo "server: https://${s}:9345" >> /etc/rancher/rke2/config.yaml
  echo "token: ${t}" >> /etc/rancher/rke2/config.yaml
fi

if [[ "${m}" ==  "master" ]] || [[ "${m}" ==  "all" ]]
then
  echo 'write-kubeconfig-mode: "0600"' >> /etc/rancher/rke2/config.yaml
  echo 'kube-apiserver-arg: "kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"' >> /etc/rancher/rke2/config.yaml
  echo "advertise-address: ${privateip}" >> /etc/rancher/rke2/config.yaml
  echo 'tls-san:' >> /etc/rancher/rke2/config.yaml
  echo "  - ${publicip}" >> /etc/rancher/rke2/config.yaml
fi
echo "node-ip: ${privateip}" >> /etc/rancher/rke2/config.yaml
echo "node-external-ip: ${publicip}" >> /etc/rancher/rke2/config.yaml
if [[ "${m}" ==  "master" ]]
then
  echo 'node-taint:' >> /etc/rancher/rke2/config.yaml
  echo '  - "CriticalAddonsOnly=true:NoExecute"' >> /etc/rancher/rke2/config.yaml
fi

echo "Applying hardening settings..."
if [[ "${m}" ==  "master" ]] || [[ "${m}" ==  "all" ]]
then
  useradd -r -c "etcd user" -s /sbin/nologin -M etcd -U
fi
cp -f /usr/local/share/rke2/rke2-cis-sysctl.conf /etc/sysctl.d/60-rke2-cis.conf
systemctl restart systemd-sysctl

if [[ "${m}" ==  "master" ]] || [[ "${m}" ==  "all" ]]
then
  echo "Starting RKE2 Server..."
  systemctl start rke2-server.service
  echo "Setting kubectl..."
  ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl
  mkdir -p ~/.kube/
  ln -s /var/lib/rancher/rke2/server/cred/admin.kubeconfig ~/.kube/config
else
  echo "Starting RKE2 agent...."
  systemctl start rke2-agent.service
fi

if [[ -z "${s}" ]]
then
  token=`cat /var/lib/rancher/rke2/server/token`
  echo "Bootstrap info, please add the following flags for the rest of the nodes in this cluster"
  echo "-s ${privateip} -t ${token}"
fi