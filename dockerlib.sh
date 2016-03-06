#!/bin/bash
#####################################################################
#
# Docker bash library to facilitate development
#
# Notes: 
# 
# Maintainer: Samuel Cozannet <samnco@gmail.com> 


#
#####################################################################

# Validating I am running on debian-like OS
[ -f /etc/debian_version ] || {
    echo "We are not running on a Debian-like system. Exiting..."
    exit 0
}

# Load Configuration
MYNAME="$(readlink -f "$0")"
MYDIR="$(dirname "${MYNAME}")"

FACILITY=${FACILITY:-"local0"}
LOGTAG=${LOGTAG:-"unknown"}
MIN_LOG_LEVEL=${MIN_LOG_LEVEL:-"debug"}

MYLIB="${MYDIR}/bashlib.sh"

for file in "${MYLIB}" ; do
	[ -f ${file} ] && source ${file} || { 
		echo "Could not find required file. Exiting..."
		exit 1
	}
done 

# add_auth: adds the content of a dockercfg file (from quay.io)
#   to the system dockerfile
# usage add_auth <src_dockercfg> <target_dockercfg>
function docker::lib::add_auth() {
    local SOURCE=$1
    shift
    local TARGET=$1
    bash::lib::log crit This feature is not implemented yet
}

# docker-cleanup: deletes all stopped containers and untagged images
#	from the local system
function docker::lib::docker-cleanup() {
	bash::lib::log warn  This action will delete every container on your system. Continue?

	# remove all stopped containers
	docker rm $(docker ps -a -q) 2>/dev/null && \
		bash::lib::log info All container deleted || \
		bash::lib::log info Could not delete all containers. Check manually to find the error

	# Delete all untagged images	
	docker rmi -f $(docker images | grep "^<none>" | awk '{print $3}') 2>/dev/null && \
		bash::lib::log info All container deleted || \
		bash::lib::log info Could not delete all containers. Check manually to find the error

}