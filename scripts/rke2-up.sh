#!/bin/bash

usage() { echo "Usage: $0 [-p PrivateIP|auto] [-P PublicIP|auto|disable] [-m master|worker|all] [-v v1.21.6+rke2r1] [-s 192.168.1.100] [-t K1075c2da4946626e73...] " 1>&2; exit 1; }

while getopts ":m:v:s:t:p:P:" o; do
    case "${o}" in
        m)
            m=${OPTARG}
            ((m == master || m == worker || m == all)) || usage
            ;;
        v)
            v=${OPTARG}
            ;;
        p)
            p=${OPTARG}
            if [[ -z "${p}" ]]; then
                p="auto"
            fi
            ;;
        P)
            P=${OPTARG}
            if [[ -z "${P}" ]]; then
                P="auto"
            fi
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

test-ip() {
  if [[ ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid IP address"
    return 1
  fi
  if [[ $1 == '127.0.0.1' ]]; then
    echo "Found loopback"
    return 1
  fi
  return 0
}

if [ -z "${v}" ];
then
  export INSTALL_RKE2_VERSION=""
else
  export INSTALL_RKE2_VERSION="${v}"
fi

if [[ "${m}" ==  "master" ]] || [[ "${m}" ==  "all" ]]
then
  echo "Installing RKE2 Server...."
  curl -sfL https://get.rke2.io | sh -
  echo "Setting up RKE2 Server service..."
  systemctl enable rke2-server.service
else
  echo "Installing RKE2 agent...."
  curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
  echo "Setting up RKE2 agent service..."
  systemctl enable rke2-agent.service
fi

echo "Collecting IPs..."
if [[ "${p}" == "auto" ]]
then
  echo "Checking using hostname -i..."
  privateip=`hostname -i | awk '{print $1}'`
  if test-ip $privateip; then
    echo "Found private IP: $privateip"
  else
    privateip=""
  fi
  if [[ $privateip == "" ]]; then
    echo "Checking using ip addr show eth0..."
    privateip=$(ip addr show eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '  ')
    if test-ip $privateip; then
      echo "Found private IP: $privateip"
    else
      privateip=""
    fi
  fi
  if [[ $privateip == "" ]]; then
    echo "Checking using ip addr show ens160..."
    privateip=$(ip addr show ens160 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '  ')
    if test-ip $privateip; then
      echo "Found private IP: $privateip"
    else
      privateip=""
    fi
  fi
  if [[ $privateip == "" ]]; then
    echo "Checking using ip addr show bond0..."
    privateip=$(ip addr show bond0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '  ')
    if test-ip $privateip; then
      echo "Found private IP: $privateip"
    else
      privateip=""
    fi
  fi
else
  privateip=$p
fi

if [[ -z $privateip ]]
then
  echo "No private IP detected or set"
  exit 2
fi
if [[ "${P}" == "auto" ]]; then
  publicip=`curl -s ifconfig.me.`
elif [[ ! -z $P ]]; then
  publicip=$P
  if test-ip $publicip; then
    echo "Found public IP: $publicip"
  else
    publicip=""
  fi
elif [[ "${P}" == "disable" ]]; then
  echo "Public IP disabled"
  publicip=""
else
  echo "No public IP detected or set"
  exit 2
fi
echo "Public IP: $publicip"

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
  echo 'profile: "cis-1.5"' >> /etc/rancher/rke2/config.yaml  
  echo 'selinux: true' >> /etc/rancher/rke2/config.yaml  
  echo "advertise-address: ${privateip}" >> /etc/rancher/rke2/config.yaml
  echo "node-ip: ${privateip}" >> /etc/rancher/rke2/config.yaml
fi
if [[ ! -z $publicip ]]; then
  echo 'tls-san:' >> /etc/rancher/rke2/config.yaml
  echo "  - ${publicip}" >> /etc/rancher/rke2/config.yaml  
  echo "node-external-ip: ${publicip}" >> /etc/rancher/rke2/config.yaml
fi
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
  echo "::Bootstrap info::"
  if [[ "${m}" ==  "all" ]]
  then
    echo "Run the following command on the rest of the all nodes in the cluster. NOTE: You should join nodes one at a time."
    echo "rke2-up -m all -v ${v} -s ${privateip} -t ${token}"
  else
    echo "Run the following command on the rest of the master nodes in the cluster. NOTE: You should join master nodes one at a time."
    echo "rke2-up -m master -v ${v} -s ${privateip} -t ${token}"
    echo "Run the following command on each worker nodes. Note: You can run this command on multiple nodes at the same time."
    echo "rke2-up -m worker -v ${v} -s ${privateip} -t ${token}"
  fi
fi