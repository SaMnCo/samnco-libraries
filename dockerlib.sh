#!/bin/bash
#####################################################################
#
# Docker bash library to facilitate development
#
# Notes: 
# 
# Maintainer: Samuel Cozannet <samuel@blended.io>, http://blended.io 
#
#####################################################################

# Load Configuration
MYNAME="$(readlink -f "$0")"
MYDIR="$(dirname "${MYNAME}")"

[ -z "${FACILITY}" ] && FACILITY="local0"
[ -z "${LOGTAG}" ] && LOGTAG="unknown"
[ -z "${MIN_LOG_LEVEL}" ] && MIN_LOG_LEVEL="debug"

# add_auth: adds the content of a dockercfg file (from quay.io)
#   to the system dockerfile
# usage add_auth <src_dockercfg> <target_dockercfg>
function add_auth() {
    local SOURCE=$1
    shift
    local TARGET=$1

}

# docker-cleanup: deletes all stopped containers and untagged images
#	from the local system
function docker-cleanup() {
	# remove all stopped containers
	docker rm $(docker ps -a -q)

	# Delete all untagged images	
	docker rmi -f $(docker images | grep "^<none>" | awk '{print $3}')
}