# rke2-up

## Go Binary
Coming soon.

## Bash script

### Install
```bash
sudo curl -o /usr/local/bin/rke2-up https://raw.githubusercontent.com/SupportTools/rke2-up/main/scripts/rke2-up.sh
sudo chmod +x /usr/local/bin/rke2-up
```
or
```bash
wget -O rke2-up https://raw.githubusercontent.com/SupportTools/rke2-up/main/scripts/rke2-up.sh
chmod +x rke2-up
sudo mv rke2-up /usr/local/bin/
```

### Help
```bash
rke2-up --help
Usage: scripts/rke2-up.sh [-p PrivateIP|auto] [-P PublicIP|auto|disable] [-m master|worker|all] [-v v1.21.6+rke2r1] [-s 10.132.191.210] [-t K1075c2da4946626e73...]
```

#### Options
-p PrivateIP: Private IP address of the node.
    auto: auto-detect the private IP address of the node.
    PrivateIP: use the specified IP address. (Exameple: 10.132.191.210)
-P PublicIP: Public IP address of the node.
    auto: auto-detect the public IP address of the node.
    disable: disable public IP address.
    PublicIP: use the specified IP address. (Exameple: 1.2.3.4)
-m master|worker|all: Type of node.
    master: Joins node as master node.
    worker: Joins node as worker node.
    all: Joins node as master node and worker node.
-v v1.21.6+rke2r1: Version of RKE.
    RKE2 Version: Use the specified version of RKE2. (Exameple: v1.21.6+rke2r1)
-s Bootstrap IP: IP address of the bootstrap node.
    Bootstrap IP: Use the specified IP address of the bootstrap node. (Exameple: 10.132.191.210) Note: This should be the private IP address of the bootstrap node.
-t Token: Token of the bootstrap node.
    Token: Use the specified token of the bootstrap node. (Exameple: K1075c2da4946626e73...)

## Creating a RKE2 cluster

### Create cluster with all nodes being master and worker

Run the following command on the first node in the new cluster to bootstrap the node.
```bash
rke2-up -m all -v v1.21.6+rke2r1
```

At the end of this command, you should see an output like this. Please save this as you will need it to join the other nodes to the cluster.
```bash
::Bootstrap info::
Run the following command on the rest of the all nodes in the cluster. NOTE: You should join nodes one at a time.
rke2-up -m all -v v1.21.6+rke2r1 -s 10.132.191.210 -t MyAFakeKey::server:YouShouldReplaceMe
```

Run the following command on the rest of the nodes in the cluster. NOTE: You should join master nodes one at a time.
```bash
rke2-up -m all -v v1.21.6+rke2r1 -s 10.132.191.210 -t MyAFakeKey::server:YouShouldReplaceMe
```

### Create cluster with separate master and worker nodes

#### Create master nodes

Run the following command on the first master node in the new cluster to bootstrap the node.
```bash
rke2-up -m master -v v1.21.6+rke2r1
```

At the end of this command, you should see an output like this. Please save this as you will need it to join the other nodes to the cluster.
```bash
::Bootstrap info::
Run the following command on the rest of the master nodes in the cluster. NOTE: You should join master nodes one at a time.
rke2-up -m master -v v1.21.6+rke2r1 -s 10.132.191.210 -t MyAFakeKey::server:YouShouldReplaceMe
Run the following command on each worker nodes. Note: You can run this command on multiple nodes at the same time.
rke2-up -m worker -v v1.21.6+rke2r1 -s 10.132.191.210 -t MyAFakeKey::server:YouShouldReplaceMe
```

Run the following command on the rest of the master nodes in the cluster. NOTE: You should join master nodes one at a time.
```bash
rke2-up -m master -v v1.21.6+rke2r1 -s 10.132.191.210 -t MyAFakeKey::server:YouShouldReplaceMe
```

#### Create worker nodes

Run the following command on each worker nodes. Note: You can run this command on multiple nodes at the same time.
```bash
rke2-up -m worker -v v1.21.6+rke2r1 -s 10.132.191.210 -t MyAFakeKey::server:YouShouldReplaceMe
```
