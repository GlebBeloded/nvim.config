#!/usr/bin/env bash
source ./lib.sh
. ./lib.sh

region="eu-west-1"
export STAGE=prod
export region
declare -a hosts
readonly retries=3

deploy() {
	local target="$1"
	local count=0
	for host in "${hosts[@]}"; do
		greet "$host"
		count=$((count + 1))
	done
	read -r answer
	echo "$target ${region:-us-east-1} $answer"
	[[ -n $region ]] && echo ok
	hosts[0]=$region
	(( count++ ))
	unset answer
}

function cleanup {
	greet "$region"
}

deploy "$region" | tee log
cleanup
