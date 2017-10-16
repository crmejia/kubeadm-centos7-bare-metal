### Install & Configure CentOS

I decided to include this part in the guide since I haven't seen many guides go over the installation in details.

#### Download CentOS 7 and prepare USB boot disk
Why CentOS 7 ? I choose CentOS just to experience the configuration part and the minimal version because I have a very small USB stick at hand. You can use other distro or the full version if you so choose.

Download from here. I used the torrent. http://isoredirect.centos.org/centos/7/isos/x86_64/
After downloading prepare the USB for booting from Linux/OSX by:
```bash
$diskutil list
$diskutil unmountDisk /dev/diskN #this should be your USB stick
$sudo dd if=<path to your ISO>/CentOS-7-x86_64-Minimal-1708.iso of=/dev/rdisk2 bs=1M
```

#### Install & Configure
Once the USB is ready, boot your machines with it. Installation is straightforward. I went with the defaults and added a simple root password. Later I realized I should have:
* Initialized the network.
* Changed the hostname
* Added a user with administrator power.
* Disable the swap partition.

I found this guide(https://www.tecmint.com/centos-7-installation/) afterwards while trying to configure the system. Here's what you have to do to setup the network, hostname, add a admin user, and disable the swap partition:

My network interface was already setup so I just had to enable it by changing `ONBOOT=yes` on `# vi /etc/sysconfig/network-scripts/ifcfg-enps`. Then I restarted the network with:
```bash
service network restart
ping -c4 google.com
```
To add the user I followed: https://www.digitalocean.com/community/tutorials/how-to-create-a-sudo-user-on-centos-quickstart

```bash
adduser admin
passwd admin
usermod -aG wheel admin #add to the admin group
su admin #switch to the new user
ls -la /root #see if it worked
```

To change the hostname simply edit `vi /etc/hostname` and add your hostname. Make sure to change when through by checking `hostname` or the environment variable `echo $HOSTNAME`. I changed mine to `serverN.centos.lan`. I had to reboot the machines to get the hostname to load.

Disable swap! If you install CentOS automatically then you must disable the swap with `sudo swapoff -a` and commenting out the swap on `/etc/fstab`. Then reboot. see here https://serverfault.com/questions/684771/best-way-to-disable-swap-in-linux

Finally, update the system with `sudo yum update && sudo yum upgrade`

#### Setup SSH with keys
Set up SSH so we can hide the cluster and just use SSH! Back up both ssh_config and sshd_config before making changes. First, Modify `/etc/ssh/ssh_config` to only use protocol 2. On the `/etc/ssh/sshd_config` disable root login by adding `PermitRootLogin no`. We are not changing the default ssh port(22) for this project.

Now, test from your dev machine. You should be able to ssh admin@IP_ADDR. To figure out the IP of your server you can do `hostname -I`. Since we are in the local machine let's go ahead and setup key based authentication. Following this guide https://www.digitalocean.com/community/tutorials/how-to-configure-ssh-key-based-authentication-on-a-linux-server

If you have not setup your keys follow the _How To Create SSH Keys_ part of the tutorial. Using ssh-copy-id we copy the keys to our server: `ssh-copy-id admin@IP_ADDR`. Then, we try to ssh again. We shouldn't be prompted for a password. Now we can disable password authentication since we have the keys `sudo vi /etc/ssh/sshd_config` and set `PasswordAuthentication no`(From the server) and `sudo service sshd restart`.

After we are done we can only access the nodes physically or from our dev machine. Try sshing from any node to other nodes and you shouldnt' be able to do it.

#### tmux

As part of my workflow, I'm using tmux. Which is a terminal multiplexer that allows me to persist my session if the ssh connection fails, among other useful things. You can install with `sudo yum install tmux`. You can follow a tutorial online at http://www.hamvocke.com/blog/a-quick-and-easy-guide-to-tmux/

 **Repeat this process for each server node!**

### Boostraping the Cluster

Now that we have the nodes ready we proceed from our dev machine to install kubeadm by sshing. Here, I followed the official guide: https://kubernetes.io/docs/setup/independent/install-kubeadm/

#### Set firewall rules
The guide has a table with the ports that are used by the nodes. So need to add them to the allowed ports on the firewall.

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

Finally let's bootstrap the cluster with `kubeadm init`. If no issues arise, we'll get some instructions at the end of the run to copy our config to our home directory. Also, a command with our token to have the other nodes join the cluster:

```bash
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  kubeadm join --token <token> master-ip:6443 --discovery-token-ca-cert-hash <hash>
```
If the init process hangs I suggest you read the logs from the init but also the log from the kubelet and docker with: `journalctl -xeu docker` and `journalctl -xeu kubelet`.

#### `kubeadm init` troubleshooting

Make sure:
* `getenforce` is _Permissive_, that is `setenforce 0`. Everytime your reset your a node this flag is set.
* Make sure the swap partition is disabled! That is `swapoff -a`. You can check by running `free` the swap should be size 0.
* If you see a "refusing connection" of the docker log. Check the port that is trying to connect. It happened to me that the port was not listed on the table and I had to add it.

I learned all these the hard way. Hopefully, you can save hours of digging. If these don't help you, there's google the issue and if you find no solace I suggest you reach out to the #kubeadm slack channel.

#### Install a Pod network
We are advised to install a pod network before having the nodes join. I chose to install Weave Net. Mostly because the other options required to pass `--pod-network-cidr=` to `kubeadm init`. To install Weave Net:
```bash
export kubever=$(kubectl version | base64 | tr -d '\n')
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever"
```
Once the pods are running you can start joining nodes. `kubectl get pods --all-namespaces`

#### Tainting the master?

According to the guide, no pods are scheduled on the master for security reasons. I'm going to stick to this policy but you can taint the master node and schedule with: `kubectl taint nodes --all node-role.kubernetes.io/master-`

### Join the nodes

So we now ssh into our nodes and `kudeadm join` the cluster. That of course requires to install Docker, kubxxx, etc.

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

In my case, kept getting docker connection errors. So I had to add another port to the firewall.
```
firewall-cmd --permanent --add-port=6783/tcp
firewall-cmd --reload
```
Some key commands are `kubectl get pods --all-namespaces -o wide` and `kubectl -n NAMESPACE describe pod PODNAME`. Similary, `journalctl -xeu kubelet` and `journalctl -xeu docker`. These commands give access to the logs for basic troubleshooting. You might run into issues, as I have, but with patience, a search engine, and the #kubeadm slack channel you can overcome these issues too.
Repeat this process for each node. Once Completed you can see the nodes by running `kubectl get nodes` from master.

#### Take the cluster for a Ride(Deploy an APP)

In the main tutorial I've been following they deploy sock-shop. However, I ran into app issues. So, I decided to try a different app in this case the guest book example: https://github.com/kubernetes/examples/tree/master/guestbook-go
