#!/bin/bash

set -e

sudo apt-get update
sudo apt-get -y dist-upgrade
sudo apt-get -y install joe unzip cmake gradle openjdk-8-jdk openjdk-8-jre-headless
sudo apt -y install tasksel
sudo tasksel install ubuntu-desktop
sudo snap install android-studio --classic







#mkdir -p ~/android-sdk-linux/platform-tools
#cd ~/android-sdk-linux
#wget https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip
#unzip sdk-tools-linux-4333796.zip

#cd ~
#wget https://github.com/SFML/SFML/archive/2.3.x.zip
#unzip 2.3.x.zip


#export ANDROID_HOME="~/android-sdk-linux"
#export PATH="$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$PATH"

#echo 'export ANDROID_HOME="~/android-sdk-linux"' >> ~/.bashrc
#echo 'export PATH="$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools/:$PATH"' >> ~/.bashrc

#yes | sdkmanager --licenses
#sdkmanager ndk-bundle
#sdkmanager platform-tools
#sdkmanager "system-images;android-21;default;armeabi-v7a"


#android update sdk --all --filter sys-img-armeabi-v7a-android-23 --no-ui --force --use-sdk-wrapper

sudo service gdm3 start
