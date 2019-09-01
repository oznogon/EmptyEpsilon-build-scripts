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


# Disable some services to decrease boot time
chroot ${TARGET_NFS_DIR} systemctl disable rsyslog


# Install tools in NFS root required to build EE.
chroot ${TARGET_NFS_DIR} apt-get update
chroot ${TARGET_NFS_DIR} apt-get -y install git mesa-utils rxvt build-essential libx11-dev cmake libxrandr-dev mesa-common-dev libglu1-mesa-dev libudev-dev libglew-dev libjpeg-dev libfreetype6-dev libopenal-dev libsndfile1-dev libxcb1-dev libxcb-image0-dev
# Install basic X setup in NFS root to allow us to run EE later on.
chroot ${TARGET_NFS_DIR} apt-get -y install xserver-xorg-core xserver-xorg-video-amdgpu  xserver-xorg-input-all  xinit alsa-base alsa-utils

# Download&install SFML,EE,SP (This takes a while)
chroot ${TARGET_NFS_DIR} git clone https://github.com/daid/EmptyEpsilon.git /root/EmptyEpsilon
chroot ${TARGET_NFS_DIR} git clone https://github.com/daid/SeriousProton.git /root/SeriousProton
#wget http://www.sfml-dev.org/files/SFML-2.3.2-sources.zip -O ${TARGET_NFS_DIR}/root/SFML-2.3.2-sources.zip
#unzip ${TARGET_NFS_DIR}/root/SFML-2.3.2-sources.zip -d ${TARGET_NFS_DIR}/root/
chroot ${TARGET_NFS_DIR} git clone https://github.com/SFML/SFML.git -b "2.5.x" "/root/SFML"
chroot ${TARGET_NFS_DIR} sh -c 'cd /root/SFML && cmake . && make -j 3 && make install && ldconfig'
mkdir -p ${TARGET_NFS_DIR}/root/EmptyEpsilon/_build
chroot ${TARGET_NFS_DIR} sh -c 'cd /root/EmptyEpsilon/_build && cmake .. -DSERIOUS_PROTON_DIR=/root/SeriousProton/ && make -j 3'
# Create a symlink for the final executable.
chroot ${TARGET_NFS_DIR} ln -s _build/EmptyEpsilon /root/EmptyEpsilon/EmptyEpsilon
# Create a symlink to store the options.ini file in /tmp/, this so the client can load a custom file.
chroot ${TARGET_NFS_DIR} ln -s /tmp/options.ini /root/EmptyEpsilon/options.ini

cat > ${TARGET_NFS_DIR}/root/setup_option_file.sh <<-EOT
#!/bin/sh
MAC=\$(cat /sys/class/net/*/address | grep -v 00\:00\:00 | sed 's/://g')
if [ -e /root/configs/\${MAC}.ini ]; then
    cp /root/configs/\${MAC}.ini /tmp/options.ini
else
    echo "instance_name=\${MAC}" > /tmp/options.ini
fi
EOT
chmod +x ${TARGET_NFS_DIR}/root/setup_option_file.sh

#create eescript
cat > ${TARGET_NFS_DIR}/root/setup_option_file.sh <<-EOT
#!/bin/sh
MAC=\$(cat /sys/class/net/*/address | grep -v 00\:00\:00 | sed 's/://g')
if [ -e /root/configs/\${MAC}.ini ]; then
    cp /root/configs/\${MAC}.ini /tmp/options.ini
else
    echo "instance_name=\${MAC}" > /tmp/options.ini
fi
EOT
chmod +x ${TARGET_NFS_DIR}/root/setup_option_file.sh

# Create an install a systemd unit that runs EE.
cat > ${TARGET_NFS_DIR}/etc/systemd/system/emptyepsilon.service <<-EOT
[Unit]
Description=EmptyEpsilon

[Service]
Environment=XAUTHORITY=/tmp/.xauthority
TimeoutStartSec=0
WorkingDirectory=/root/EmptyEpsilon
ExecStartPre=/root/setup_option_file.sh
ExecStart=/usr/bin/startx /root/EmptyEpsilon/EmptyEpsilon.sh -- -logfile /tmp/x.log

[Install]
WantedBy=multi-user.target
EOT
chroot ${TARGET_NFS_DIR} systemctl enable emptyepsilon.service


# Disable screen standby/blanking
cat > ${TARGET_NFS_DIR}/etc/X11/xorg.conf <<-EOT
Section "Monitor"
    Identifier "LVDS0"
    Option "DPMS" "false"
EndSection

Section "ServerLayout"
    Identifier "ServerLayout0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime"     "0"
    Option "BlankTime"   "0"
EndSection
EOT

# Instead of running a login shell on tty1, run a normal shell so we do not have to login with a username/password are just root. Who cares, we are on a read only system.
cat > ${TARGET_NFS_DIR}/etc/systemd/system/shell_on_tty.service <<-EOT
[Unit]
Description=Shell on TTY1
After=getty.target
Conflicts=getty@tty1.service

[Service]
Type=simple
RemainAfterExit=yes
ExecStart=/bin/bash
TimeoutStopSec=1
StandardInput=tty-force
StandardOutput=inherit
StandardError=inherit

[Install]
WantedBy=graphical.target
EOT
chroot ${TARGET_NFS_DIR} systemctl enable shell_on_tty.service
cp /vagrant/artemis.zip ${TARGET_NFS_DIR}/root/
cd ${TARGET_NFS_DIR}/root/
unzip artemis.zip

# Install the ssh server on the netboot systems, so we can remotely access them, setup a private key on the server and put the public on as authorized key in the netboot system.
# Also install avahi for easier server discovery.
chroot ${TARGET_NFS_DIR} apt-get install -y twm openssh-server x11-xserver-utils wine32 avahi-daemon avahi-utils libnss-mdns
chroot ${TARGET_NFS_DIR} apt-get clean
echo "PermitRootLogin yes" >> ${TARGET_NFS_DIR}/etc/ssh/sshd_config
if [[ ! -e $HOME/.ssh/id_rsa ]]; then
    ssh-keygen -t rsa -f $HOME/.ssh/id_rsa -N ''
fi
mkdir -p ${TARGET_NFS_DIR}/root/.ssh/
cp $HOME/.ssh/id_rsa.pub ${TARGET_NFS_DIR}/root/.ssh/authorized_keys
cat > ${TARGET_NFS_DIR}/etc/avahi/services/ee.service <<-EOT
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">EmptyEpsilon on %h</name>
  <service>
    <type>_emptyepsilon._tcp</type>
    <port>22</port>
  </service>
</service-group>
EOT


# unount for tar
umount ${TARGET_NFS_DIR}/proc
umount ${TARGET_NFS_DIR}/sys
umount ${TARGET_NFS_DIR}/dev
umount ${TARGET_NFS_DIR}/tmp

#tar up srv
tar -cjvaf /vagrant/pxe.tar.bz2 /srv/

#gzip -9 /vagrant/pxe.tar

