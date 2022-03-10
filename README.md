# rke2-up

## Bash script

### Install
curl -o /usr/local/bin/rke2-up https://raw.githubusercontent.com/rancher/rke2-up/main/scripts/build/rke2-up.sh
chmod +x /usr/local/bin/rke2-up

### Help
rke2-up --help
Usage: scripts/rke2-up.sh [-m master|worker|all] [-v v1.21.6+rke2r1] [-s 192.168.1.100] [-t K1075c2da4946626e73...]

## Creating a RKE2 cluster

### Create cluster with all nodes being master and worker

Run the following command on the first node in the new cluster to bootstrap the node.
```
rke2-up -m all -v v1.21.6+rke2r1 -s
```

At the end of this command, you should see an output like this. Please save this as you will need it to join the other nodes to the cluster.
```
...
Bootstrap info, please add the following flags for the rest of the nodes in this cluster
-s 10.128.0.6 -t MyAFakeKey::server:YouShouldReplaceMe
```

Run the following command on the rest of the nodes in the cluster one at a time.
```
build-rke2 -m all -v v1.21.6+rke2r1 -s 10.128.0.6 -t MyAFakeKey::server:YouShouldReplaceMe
```

### Create cluster with separate master and worker nodes

#### Create master nodes

Run the following command on the first master node in the new cluster to bootstrap the node.
```
rke2-up -m master -v v1.21.6+rke2r1 -s
```

At the end of this command, you should see an output like this. Please save this as you will need it to join the other nodes to the cluster.
```
...
Bootstrap info, please add the following flags for the rest of the nodes in this cluster
-s 10.128.0.6 -t MyAFakeKey::server:YouShouldReplaceMe
```

Run the following command on the rest of the master nodes in the cluster one at a time.
```
build-rke2 -m master -v v1.21.6+rke2r1 -s 10.128.0.6 -t MyAFakeKey::server:YouShouldReplaceMe
```

#### Create worker nodes

Run the following command on each worker nodes. Note: You can run this command on multiple nodes at the same time.
```
build-rke2 -m worker -v v1.21.6+rke2r1 -s 10.128.0.6 -t MyAFakeKey::server:YouShouldReplaceMe
```
