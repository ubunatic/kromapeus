#!/usr/bin/env bash
BIN=`readlink -f "$1"`
case $BIN in
	*/bin) ;;
	*)     BIN=$arg/bin;;
esac

mkdir -p $BIN
dir=`dirname $0`
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > $dir/get_helm.sh
chmod +x $dir/get_helm.sh

echo installing to $BIN
# avoid sudo using EUID=0 (requires `sh`, since var is readonly in `bash`)
sh -c "PATH=$PATH:$BIN EUID=0 HELM_INSTALL_DIR=$BIN $dir/get_helm.sh"

