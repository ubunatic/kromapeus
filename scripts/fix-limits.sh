#!/usr/bin/env bash

set -o errexit

PREFIX=scripts/kube-system
prefix() { echo "$PREFIX/$1.yaml"; }
list()   { kubectl get $@ | cut -d " " -f 1 | tail -n +2; }
filter() { all="$1"; shift; echo "$all" | grep "$@" || true; }

#Command   #Parse arguments       #Run wrapped command with remaining      #Args and #File
get()    { f=`prefix $1`;         kubectl get --export -o yaml deployment  $@        > $f; }
replace(){ f=`prefix $1`; shift;  kubectl replace --force                  $@        -f $f; }
fix()    { f=`prefix $1`; shift;  sed -i -e 's/cpu: .*/cpu: 20m/g'         $@        $f; }

PREFIX=scripts replace limit-range --namespace default &
# PREFIX=scripts replace limit-range --namespace kube-system &
kubectl scale deployment kube-dns-autoscaler --replicas 0 --namespace kube-system &
kubectl scale deployment kube-dns            --replicas 1 --namespace kube-system &
wait

# system=` list deployments --namespace kube-system`
# default=`list deployments --namespace default`
# daemons=`list daemonsets  --namespace kube-system`
# echo SYSTEM  ALL: $system
# echo DEFAULT ALL: $default
# echo DAEMONS ALL: $daemons
# 
# heapster=`filter "$system"  'heapster'`
# system=`  filter "$system"  'metrics-server\|dashboard\|event-exporter'`
# default=` filter "$default" 'prometheus\|grafana'`
# daemons=` filter "$daemons" 'fluentd\|metrics'`
# 
# echo HEAPSTER:            $heapster
# echo SYSTEM  DEPLOYMENTS: $system
# echo DEFAULT DEPLOYMENTS: $default
# echo DAEMONS:             $daemons
# 
# for res in $heapster $system; do
# 	# get     $res --namespace kube-system
# 	# fix     $res -e 's/cpu=.*/cpu=20m/g'
# 	# replace $res --namespace kube-system
# 	kubectl set resources deployment $res --namespace kube-system --requests="cpu=20m" &
# done
# 
# for res in $default; do
# 	kubectl set resources deployment $res --namespace default --requests="cpu=20m" &
# done
# 
# for res in $daemons; do
# 	kubectl set resources daemonset $res --namespace kube-system --requests="cpu=20m" &
# done
# wait
