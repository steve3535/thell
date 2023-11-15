#!/bin/bash
if [ $# -eq 0 ];then
	echo "Usage: ./setup_cri.sh <CRI_NAME>"
	exit 1
fi

if [ $1 == "containerd" ];then

  cd /opt
  CRI_NAME=$1
  version=$(curl -s https://api.github.com/repos/$CRI_NAME/$CRI_NAME/releases/latest | jq -r .tag_name|cut -d"v" -f2)
  download_url="https://github.com/$CRI_NAME/$CRI_NAME/releases/download/v$version/$CRI_NAME-$version-linux-amd64.tar.gz"
  wget $download_url
  tar Cxzvf /usr/local "$CRI_NAME-$version-linux-amd64.tar.gz"

  version_runc=$(curl -s https://api.github.com/repos/opencontainers/runc/releases/latest | jq -r .tag_name|cut -d"v" -f2)
  download_url="https://github.com/opencontainers/runc/releases/download/v$version_runc/runc.amd64"
  wget $download_url
  install -m 755 /opt/runc.amd64 /usr/local/sbin/runc

  wget https://raw.githubusercontent.com/$CRI_NAME/$CRI_NAME/main/$CRI_NAME.service -O /etc/systemd/system/$CRI_NAME.service 
  systemctl daemon-reload
  systemctl enable --now $CRI_NAME

fi




