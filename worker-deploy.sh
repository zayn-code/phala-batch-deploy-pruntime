#!/bin/bash

function installTool() {
  for package in jq curl wget unzip zip node yq dkms; do
    if ! type $package >/dev/null; then
      case $package in
      jq | curl | wget | unzip | zip | dkms)
        sudo apt-get install -y $package
        ;;
      node)
        sudo curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
        ;;
      yq)
        sudo tar -xvf /home/www/yq_linux_amd64.tar.gz -C /tmp
        sudo mv /tmp/yq_linux_amd64 /usr/bin/yq
        sudo rm /tmp/yq_linux_amd64.tar.gz
        ;;
      *)
        break
        ;;
      esac
    fi
  done
}

echo '123456' | sudo -S pwd
sudo apt update
sudo apt list --upgradable
sudo apt install docker.io -y
sudo systemctl restart docker
sudo docker -v
sudo mv /home/www/phala/docker-compose /usr/local/bin
sudo docker-compose -v
installTool
sudo cp -r /home/www/phala /opt
sudo bash /opt/phala/sgx_linux_x64_driver_2.11.0_2d2b795.bin
sudo docker-compose -f /opt/phala/docker-compose.yaml up -d

#在同步时可以添加定时任务定时重启worker，个人感觉这样会同步的快些
#sudo echo "0 */1 * * * docker restart phala-pruntime" > /home/www/phala/root
#sudo cp /home/www/phala/root /var/spool/cron/crontabs/
#sudo systemctl restart cron

sudo rm -rf /home/www/phala
