#!/usr/bin/env bash
prefix=`readlink -f "$1"`
case $prefix in
	"")    bin=./bin;;
	*/bin) bin=$prefix;;
	*)     bin=$prefix/bin;;
esac

mkdir -p $bin
dir=`dirname $0`
curl -o $dir/get_helm.sh https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get
chmod +x $dir/get_helm.sh

echo installing to $bin
# avoid sudo using EUID=0 (requires `sh`, since var is readonly in `bash`)
sh -c "PATH=$PATH:$bin EUID=0 HELM_INSTALL_DIR=$bin $dir/get_helm.sh"

