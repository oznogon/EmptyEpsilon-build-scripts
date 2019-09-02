#!/bin/bash
set -e
set -u

### Parameters for the installation.
export TARGET_NFS_DIR=/srv/nfsroot/
export TARGET_TFTP_DIR=/srv/tftp/
export MIRROR=http://ftp.debian.org/debian/
export ETH=$(ip link | grep UP | grep -v LOOPBACK | awk '{print $2}' | rev | cut -c 2- | rev)
#the first 3 octets of the /24 network
export NETWORK=10.16.0.
# Install packages that we need on the host system to install our PXE environment, which includes dnsmasq as a dhcp-server and tftp-server and nfs for the network files system.
apt-get update
apt-get -y upgrade

# Setup the nfs root in a way so we can chroot into it.
mount -t proc none ${TARGET_NFS_DIR}/proc
mount --bind /sys ${TARGET_NFS_DIR}/sys
mount --bind /dev ${TARGET_NFS_DIR}/dev
mount -t tmpfs none ${TARGET_NFS_DIR}/tmp

chroot ${TARGET_NFS_DIR} apt-get update
chroot ${TARGET_NFS_DIR} bash -c 'export DEBIAN_FRONTEND=noninteractive; export UCF_FORCE_CONFFNEW=YES;apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" dist-upgrade'

cd ${TARGET_NFS_DIR}/root/SFML
git pull
cd ${TARGET_NFS_DIR}/root/EmptyEpsilon
git pull
cd ${TARGET_NFS_DIR}/root/SeriousProton/
git pull

chroot ${TARGET_NFS_DIR} sh -c 'cd /root/SFML && cmake . && make -j 3 && make install && ldconfig'
mkdir -p ${TARGET_NFS_DIR}/root/EmptyEpsilon/_build
chroot ${TARGET_NFS_DIR} sh -c 'cd /root/EmptyEpsilon/_build && cmake .. -DSERIOUS_PROTON_DIR=/root/SeriousProton/ && make -j 3'

chroot ${TARGET_NFS_DIR} apt-get clean

# unount for tar
umount ${TARGET_NFS_DIR}/proc
umount ${TARGET_NFS_DIR}/sys
umount ${TARGET_NFS_DIR}/dev
umount ${TARGET_NFS_DIR}/tmp

#tar up srv
tar -cjvaf /vagrant/pxe.tar.bz2 /srv/

#gzip -9 /vagrant/pxe.tar

cp /vagrant/ssh/* ~/.ssh

ssh 10.16.0.2 -C rm -f /home/pi/pxe.tar.bz2
scp /vagrant/pxe.tar.bz2 10.16.0.2:/home/pi/
ssh 10.16.0.2 -C /root/update.sh