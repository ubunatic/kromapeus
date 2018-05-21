#!/usr/bin/env bash

set -o errexit

ask=false
allow=false

case "$1" in
	enable|allow|yes|true)     allow=true;;
	disable|disallow|no|false) allow=false;;
	*)                         allow=false; ask=true;;
esac

if $ask; then
	read -p "Allow pods to adminster cluster using default service account? (y|N)" key
	case $key in
		y|Y|yes) allows=true;;
		*)       allow=false;;
	esac
fi

if $allow
then kubectl create clusterrolebinding add-on-cluster-admin \
	--clusterrole=cluster-admin --serviceaccount=kube-system:default
else echo "admin-role setup skipped" 1>&2
fi
