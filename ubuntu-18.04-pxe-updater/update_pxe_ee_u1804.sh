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
apt-get -y install debootstrap zip coreutils util-linux e2fsprogs dnsmasq nfs-common nfs-kernel-server

mkdir -p ${TARGET_NFS_DIR}
mkdir -p ${TARGET_TFTP_DIR}

# Build a basic rootfs system (This takes a while)
debootstrap --arch i386 bionic ${TARGET_NFS_DIR} 

# Setup apt-get configuration on the new rootfs.
cp /etc/apt/sources.list ${TARGET_NFS_DIR}/etc/apt/sources.list
cat > ${TARGET_NFS_DIR}/etc/apt/sources.list <<-EOT
deb http://us.archive.ubuntu.com/ubuntu/ bionic main restricted

deb http://us.archive.ubuntu.com/ubuntu/ bionic-updates main restricted

deb http://us.archive.ubuntu.com/ubuntu/ bionic universe
deb http://us.archive.ubuntu.com/ubuntu/ bionic-updates universe

deb http://us.archive.ubuntu.com/ubuntu/ bionic multiverse
deb http://us.archive.ubuntu.com/ubuntu/ bionic-updates multiverse

deb http://us.archive.ubuntu.com/ubuntu/ bionic-backports main restricted universe multiverse


deb http://security.ubuntu.com/ubuntu bionic-security main restricted
deb http://security.ubuntu.com/ubuntu bionic-security universe
deb http://security.ubuntu.com/ubuntu bionic-security multiverse
#deb ${MIRROR} stable main contrib non-free
#deb-src ${MIRROR} stable main contrib non-free

#deb http://security.debian.org/ stable/updates main contrib non-free
#deb-src http://security.debian.org/ stable/updates main contrib non-free

#deb http://ftp.debian.org/ stable-updates main contrib non-free
#deb-src http://ftp.debian.org/ stable-updates main contrib non-free
EOT

# Setup the PXE network interfaces configuration. This is the configuration the clients will use to bring up their network.
# Assumes that they have a single LAN card.
cat > ${TARGET_NFS_DIR}/etc/network/interfaces <<-EOT
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp
EOT

# Setup the nfs root in a way so we can chroot into it.
mount -t proc none ${TARGET_NFS_DIR}/proc
mount --bind /sys ${TARGET_NFS_DIR}/sys
mount --bind /dev ${TARGET_NFS_DIR}/dev
mount -t tmpfs none ${TARGET_NFS_DIR}/tmp

cp /etc/resolv.conf ${TARGET_NFS_DIR}/etc/resolv.conf
# Setup a hostname on the NFS root (This might confuse some applications, as the hostname is random on each read)
echo "pxeclient" > ${TARGET_NFS_DIR}/etc/hostname
echo "127.0.0.1 pxeclient" >> ${TARGET_NFS_DIR}/etc/hosts
# Setup /tmp as tmpfs on the netboot system, so we have a place to write things to.
cat > ${TARGET_NFS_DIR}/etc/fstab <<-EOT
tmpfs /tmp  tmpfs  nodev,nosuid 0  0
EOT

# Get syslinux/pxelinux, which contains a lot of files, but we need some of these to get PXE booting to work.
sudo apt-get -y install pxelinux syslinux-efi
mkdir -p ${TARGET_TFTP_DIR}/bios
mkdir -p ${TARGET_TFTP_DIR}/efi32
mkdir -p ${TARGET_TFTP_DIR}/efi64
cp /usr/lib/PXELINUX/pxelinux.0 ${TARGET_TFTP_DIR}/bios/
cp /usr/lib/syslinux/modules/bios/*.c32 ${TARGET_TFTP_DIR}/bios/
cp /usr/lib/SYSLINUX.EFI/efi32/syslinux.efi ${TARGET_TFTP_DIR}/efi32/
cp /usr/lib/syslinux/modules/efi32/*.e32 ${TARGET_TFTP_DIR}/efi32/
cp /usr/lib/SYSLINUX.EFI/efi64/syslinux.efi ${TARGET_TFTP_DIR}/efi64/
cp /usr/lib/syslinux/modules/efi64/*.e64 ${TARGET_TFTP_DIR}/efi64/

# Setup the pxelinux configuration
mkdir -p ${TARGET_TFTP_DIR}/pxelinux.cfg
cat > ${TARGET_TFTP_DIR}/pxelinux.cfg/default <<-EOT
DEFAULT linux
LABEL linux
KERNEL vmlinuz.img
APPEND ro root=/dev/nfs nfsroot=${NETWORK}2:${TARGET_NFS_DIR} initrd=initrd.img
EOT
ln -s ${TARGET_TFTP_DIR}/pxelinux.cfg ${TARGET_TFTP_DIR}/bios/pxelinux.cfg
ln -s ${TARGET_TFTP_DIR}/pxelinux.cfg ${TARGET_TFTP_DIR}/efi32/pxelinux.cfg
ln -s ${TARGET_TFTP_DIR}/pxelinux.cfg ${TARGET_TFTP_DIR}/efi64/pxelinux.cfg

ln -s ${TARGET_TFTP_DIR}/vmlinuz.img ${TARGET_TFTP_DIR}/bios/vmlinuz.img
ln -s ${TARGET_TFTP_DIR}/vmlinuz.img ${TARGET_TFTP_DIR}/efi32/vmlinuz.img
ln -s ${TARGET_TFTP_DIR}/vmlinuz.img ${TARGET_TFTP_DIR}/efi64/vmlinuz.img

ln -s ${TARGET_TFTP_DIR}/initrd.img ${TARGET_TFTP_DIR}/bios/initrd.img
ln -s ${TARGET_TFTP_DIR}/initrd.img ${TARGET_TFTP_DIR}/efi32/initrd.img
ln -s ${TARGET_TFTP_DIR}/initrd.img ${TARGET_TFTP_DIR}/efi64/initrd.img

# Setup vmlinuz.img kernel in ${TARGET_TFTP_DIR}
chroot ${TARGET_NFS_DIR} apt-get update
#chroot ${TARGET_NFS_DIR} apt-get -y install linux-image-686-pae firmware-linux-nonfree
chroot ${TARGET_NFS_DIR} bash -c 'export DEBIAN_FRONTEND=noninteractive; export UCF_FORCE_CONFFNEW=YES;apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" install linux-image-generic'
cp ${TARGET_NFS_DIR}/boot/vmlinuz* ${TARGET_TFTP_DIR}/vmlinuz.img
cp ${TARGET_NFS_DIR}/boot/initrd.img* ${TARGET_TFTP_DIR}/initrd.img
chmod 644 ${TARGET_TFTP_DIR}/vmlinuz.img
chmod 644 ${TARGET_TFTP_DIR}/initrd.img

# unount for tar
umount ${TARGET_NFS_DIR}/proc
umount ${TARGET_NFS_DIR}/sys
umount ${TARGET_NFS_DIR}/dev
umount ${TARGET_NFS_DIR}/tmp

#tar up srv
tar -cvaf /vagrant/pxe.tar /srv/

gzip -9 /vagrant/pxe.tar

