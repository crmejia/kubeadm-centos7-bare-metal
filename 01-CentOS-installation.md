### Install & Configure CentOS

I decided to include this part in the guide since I haven't seen many guides go
over the installation in details.

#### Download CentOS 7 and prepare USB boot disk
Why CentOS 7 ? I choose CentOS just to experience the configuration part and the
minimal version because I have a very small USB stick at hand. You can use other
distro or the full version if you so choose.

Download from [here](http://isoredirect.centos.org/centos/7/isos/x86_64/). I used the torrent.
After downloading prepare the USB for booting from Linux/OSX by:
```bash
$diskutil list
$diskutil unmountDisk /dev/diskN #this should be your USB stick
$sudo dd if=<path to your ISO>/CentOS-7-x86_64-Minimal-1708.iso of=/dev/rdisk2 bs=1M
```

#### Install & Configure
Once the USB is ready, boot your machines with it. Installation is
straightforward. I went with the defaults and added a simple root password.
Later I realized I should have:
* Initialized the network.
* Set up a static IP, so is easier to ssh down the line.(or don't be so strict
  with ssh policy)
* Changed the hostname
* Added a user with administrator power.
* Disable the swap partition.


I found this [guide](https://www.tecmint.com/centos-7-installation/) afterwards while trying to configure the system. Here's what you have to do to setup the network, hostname, add a
admin user, and disable the swap partition:

My network interface was already setup so I just had to enable it by changing
`ONBOOT=yes` on `# vi /etc/sysconfig/network-scripts/ifcfg-enps`. Then I
restarted the network with:
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

To change the hostname simply edit `vi /etc/hostname` and add your hostname.
Make sure to change when through by checking `hostname` or the environment
variable `echo $HOSTNAME`. I changed mine to `serverN.centos.lan`. I had to
reboot the machines to get the hostname to load.

Disable swap! If you install CentOS automatically then you must disable the swap
with `sudo swapoff -a` and commenting out the swap on `/etc/fstab`. Then reboot.
See [here](https://serverfault.com/questions/684771/best-way-to-disable-swap-in-linux)

Finally, update the system with `sudo yum update && sudo yum upgrade`

#### Setup SSH with keys
Set up SSH so we can hide the cluster and just use SSH! Back up both ssh_config
and sshd_config before making changes. First, Modify `/etc/ssh/ssh_config` to
only use protocol 2. On the `/etc/ssh/sshd_config` disable root login by adding
`PermitRootLogin no`. We are not changing the default ssh port(22) for this
project.

Now, test from your dev machine. You should be able to ssh admin@IP_ADDR. To
figure out the IP of your server you can do `hostname -I`. Since we are in the
local machine let's go ahead and setup key based authentication. Following this
[guide](https://www.digitalocean.com/community/tutorials/how-to-configure-ssh-key-based-authentication-on-a-linux-server)

If you have not setup your keys follow the _How To Create SSH Keys_ part of the
tutorial. Using ssh-copy-id we copy the keys to our server:
`ssh-copy-id admin@IP_ADDR`. Then, we try to ssh again. We shouldn't be prompted
for a password. Now we can disable password authentication since we have the
keys `sudo vi /etc/ssh/sshd_config` and set
`PasswordAuthentication no`(From the server) and `sudo service sshd restart`.

After we are done we can only access the nodes physically or from our dev
machine. Try sshing from any node to other nodes and you shouldnt' be able to
do it.

#### tmux

As part of my workflow, I'm using tmux. Which is a terminal multiplexer that
allows me to persist my session if the ssh connection fails, among other useful
things. You can install with `sudo yum install tmux`. You can follow a tutorial
[online](http://www.hamvocke.com/blog/a-quick-and-easy-guide-to-tmux/)

 **Repeat this process for each server node!**
