#!/bin/bash

#config
#woker的IP前缀
workerIpPrefix=192.168.2
#worker登录账号
workerUsername=www
#worker登录密码
workerPassword=123456
#备份目录
backupDir=/data-backup/back/khala-pruntime-data
#初始质押
initPledge=1800000000000000
#worker名称前缀（自定义，方便识别备注啥的，或者直接命名worker也行）
prbIpSuffix=worker
#prb的peerId
peerId=

#批量备份worker数据
function batchBackup() {
  read -p "请输入要备份的worker的IP段(例如:10-20): " ips
  IPStart=$(echo $ips | awk -F '-' '{print $1}')
  IPEnd=$(echo $ips | awk -F '-' '{print $2}')
  error=""
  for ip in $(seq $IPStart +1 $IPEnd); do
    server=$workerIpPrefix.$ip
    remote=$workerUsername@$server
    backup $remote $prbIpSuffix $ip
    if [ $? -ne 0 ]; then
      error="$error IP：$ip 备份过程中错误 \n"
    fi
  done

  echo -e "\e[33m------------------------------\e[0m"
  echo -e "\e[33m|  检查备份结果    |\e[0m"
  echo -e "\e[33m------------------------------\e[0m"

  for workerDir in $(ls $backupDir); do
    fileCount=$(ls "$backupDir/$workerDir" | wc -l)
    if [ $fileCount -ne 3 ]; then
      echo "目录：$workerDir 中文件个数错误"
    fi
  done
  echo -e $error
}

#备份操作
function backup() {
  if [ ! -d $backupDir/$2-$3/ ]; then
    mkdir $backupDir/$2-$3/
  fi
  auto_password "ssh -t $1 sudo docker stop phala-pruntime"
  sleep 2
  scp -r $1:/var/khala-pruntime-data/* $backupDir/$2-$3/
  isSuccess=$(echo $?)
  auto_password "ssh -t $1 sudo docker start phala-pruntime"
  return $isSuccess
}

#开始部署
function startDeploy() {
  read -p "请输入IP段(格式：10-17): " IPs
  IPStart=$(echo $IPs | awk -F '-' '{print $1}')
  IPEnd=$(echo $IPs | awk -F '-' '{print $2}')
  for ip in $(seq $IPStart +1 $IPEnd); do
    server=$workerIpPrefix.$ip
    remote=$workerUsername@$server
    phalaPath=/home/$workerUsername/phala
    auto_password "ssh-copy-id $remote"
    ssh -t $remote mkdir $phalaPath
    scp /usr/local/bin/docker-compose $remote:$phalaPath
    scp -r ./* $remote:$phalaPath
    ssh -t $remote /bin/bash $phalaPath/worker-deploy.sh
  done
}

#免密执行
function auto_password() {
  expect -c "set timeout -1;
          spawn $1;
          expect {
              *fingerprint])?* {send -- yes\r;exp_continue;}
              *password* {send -- $workerPassword\r;exp_continue;}
              eof        {exit 0;}
          }"
}

#添加到prb系统中
function addPrbService() {
  read -p "请输入矿池PID: " pid
  read -p "请输入worker的IP段(20-30): " ips
  read -p "请输入助记词: " mnemonic
  ipStart=$(echo $ips | awk -F '-' '{print $1}')
  ipEnd=$(echo $ips | awk -F '-' '{print $2}')
  workerStr="{\"workers\":["
  for ip in $(seq $ipStart +1 $ipEnd); do
    workerStr="$workerStr{\"pid\": $pid,\"name\": \"$prbIpSuffix-$ip\",\"endpoint\": \"http://$workerIpPrefix.$ip:8000\",\"enabled\": true,\"stake\": \"$initPledge\",\"syncOnly\":false}"

    if [ $ip -ne $ipEnd ]; then
      workerStr="$workerStr,"
    fi

  done
  workerStr="$workerStr]}"

  curl --location --request POST "http://127.0.0.1:3000/ptp/proxy/$peerId/CreateWorker" \
    --header 'Content-Type: application/json' \
    --data-raw "$workerStr"

  docker restart phala-prb_lifecycle_1
}

while true; do
  echo -e "\e[33m------------------------------\e[0m"
  echo -e "\e[33m|  Zayn 集群脚本    |\e[0m"
  echo -e "\e[33m|  Author @zayn QQ972858472    |\e[0m"
  echo -e "\e[33m------------------------------\e[0m"
  cat <<EOF
(1) 批量开始部署worker
(2) 添加到prb系统中
(3) 批量备份worker数据
(0) 退出
================================================================
EOF
  read -p "请输入要执行的选项: " input
  case $input in
  1)
    startDeploy
    ;;
  2)
    addPrbService
    ;;
  3)
    batchBackup
    ;;
  *)
    break
    ;;
  esac
done


