### Boostraping the Cluster

Now that we have the nodes ready we proceed from our dev machine to install
kubeadm by sshing. Here, I followed the official [guide](https://kubernetes.io/docs/setup/independent/install-kubeadm/)

#### Set firewall rules
The guide has a table with the ports that are used by the nodes. So need to add
them to the allowed ports on the firewall.

```bash
sudo firewall-cmd --permanent --add-port=2379-2380/tcp
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=10251/tcp
sudo firewall-cmd --permanent --add-port=10252/tcp
sudo firewall-cmd --permanent --add-port=10255/tcp
sudo firewall-cmd --reload
```
#### Install Docker, kubeadm, kubectl, and the kubelet

```
#Docker
yum install -y docker
systemctl enable docker && systemctl start docker
```
Now to install kubeadm, kubectl, kubelet run as root
```
sudo -i
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
setenforce 0
yum install -y kubelet kubeadm kubectl
systemctl enable kubelet && systemctl start kubelet
```

Finally let's bootstrap the cluster with `kubeadm init`. If no issues arise,
we'll get some instructions at the end of the run to copy our config to our home
directory. Also, a command with our token to have the other nodes join the
cluster:

```bash
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  kubeadm join --token <token> master-ip:6443 --discovery-token-ca-cert-hash <hash>
```
If the init process hangs I suggest you read the logs from the init but also
the log from the kubelet and docker with: `journalctl -xeu docker`
and `journalctl -xeu kubelet`.

#### `kubeadm init` troubleshooting

Make sure:
* `getenforce` is _Permissive_, that is `setenforce 0`. Everytime your reset
your a node this flag is set.
* Make sure the swap partition is disabled! That is `swapoff -a`. You can check
by running `free` the swap should be size 0.
* If you see a "refusing connection" of the docker log. Check the port that is
trying to connect. It happened to me that the port was not listed on the table
and I had to add it.

I learned all these the hard way. Hopefully, you can save hours of digging. If
these don't help you, there's google the issue and if you find no solace I
suggest you reach out to the #kubeadm slack channel.

#### Install a Pod network
We are advised to install a pod network before having the nodes join. I chose to
install Weave Net. Mostly because the other options required to pass
`--pod-network-cidr=` to `kubeadm init`. To install Weave Net:
```bash
export kubever=$(kubectl version | base64 | tr -d '\n')
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever"
```
Once the pods are running you can start joining nodes.
`kubectl get pods --all-namespaces`

#### Tainting the master?

According to the guide, no pods are scheduled on the master for security
reasons. I'm going to stick to this policy but you can taint the master node and
schedule with: `kubectl taint nodes --all node-role.kubernetes.io/master-`

### Join the nodes

So we now ssh into our nodes and `kudeadm join` the cluster. That of course
requires to install Docker, kubxxx, etc.

```bash
#Add the following ports:
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=10255/tcp
sudo firewall-cmd --permanent --add-port=30000-32767/tcp
sudo firewall-cmd --reload

#install and enable Docker
sudo yum install -y docker
sudo systemctl enable docker && systemctl start docker

#install kubeadm
sudo -i
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

#notice no kubectl
yum install -y kubelet kubeadm


#finally join the node
setenforce 0
swapoff -a
kubeadm join --token <token> <master-ip>:<master-port>
```

In my case, kept getting docker connection errors. So I had to add another port
to the firewall.
```
firewall-cmd --permanent --add-port=6783/tcp
firewall-cmd --reload
```
Some key commands are `kubectl get pods --all-namespaces -o wide` and
`kubectl -n NAMESPACE describe pod PODNAME`. Similary, `journalctl -xeu kubelet`
and `journalctl -xeu docker`. These commands give access to the logs for basic
troubleshooting. You might run into issues, as I have, but with patience, a
search engine, and the #kubeadm slack channel you can overcome these issues too.

**Repeat this process for each node. Once Completed you can see the nodes by
running `kubectl get nodes` from master.**
