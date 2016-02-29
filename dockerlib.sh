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

# Load Configuration
MYNAME="$(readlink -f "$0")"
MYDIR="$(dirname "${MYNAME}")"
DOCKER_KEY="58118E89F3A912897C070ADBF76221572C52609D"
DOCKER_COMPOSE="1.6.2"
DOCKER_MACHINE="0.6.0"

[ -z "${FACILITY}" ] && FACILITY="local0"
[ -z "${LOGTAG}" ] && LOGTAG="unknown"
[ -z "${MIN_LOG_LEVEL}" ] && MIN_LOG_LEVEL="debug"

[ -f "${MYDIR}/../lib/bashlib.sh" ] && source "${MYDIR}/../lib/bashlib.sh"
UBUNTU_CODENAME="$(get_ubuntu_codename)"

case ${UBUNTU_CODENAME} in
	precise )
		log warn This requires a reboot. Please press [Yn] and [ENTER] to continue
		read NEXT
		case ${NEXT} in 
			Y | y )
				apt-get update -qq && \
				apt-get install -yqq apparmor \
					linux-image-extra-$(uname -r) \
					linux-image-generic-lts-trusty \
					linux-headers-generic-lts-trusty \
				log warn Now rebooting machine. Please restart process afterward
				reboot now
			;;
			* )
			die Aborting. Nothing installed. 
			;;
	;;
	trusty )
		apt-get update -qq && \
		apt-get install -yqq apparmor \
			linux-image-extra-$(uname -r)
	;;
	wily )
		apt-get update -qq && \
		apt-get install -yqq apparmor \
			linux-image-extra-$(uname -r)
	;;
	* )
	;;
esac		

# Test if Docker is installed or installs it silently
# usage ensure_gcloud_or_install
function ensure_docker_or_install() {
    local CMD=docker
    hash $CMD 2>/dev/null || {
    	ensure_cmd_or_install_package_apt curl curl
    	log warn Docker not available. Attempting to install. 
    	apt-get update -qq && \
    	apt-get install -yqq apt-transport-https ca-certificates linux-image-extra-$(uname -r)
    	apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "${DOCKER_KEY}"
    	echo "deb https://apt.dockerproject.org/repo ubuntu-${UBUNTU_CODENAME} main" > /etc/apt/sources.list.d/docker.list 
    	apt-get update -qq && \
    	apt-get install -yqq docker-engine
    	[ `grep docker /etc/group` ] || groupadd docker 
    	usermod -aG docker ${USER}
    	newgrp ${USER}
    	log info "Successfully installed docker-engine"
    }

    local CMD=docker-machine
    hash $CMD 2>/dev/null || {
    	log warn docker-machine not available. Attempting to install. 
    	curl -L https://github.com/docker/machine/releases/download/v"${DOCKER_MACHINE}"/docker-machine-`uname -s`-`uname -m` > /usr/local/bin/docker-machine && \
		chmod +x /usr/local/bin/docker-machine && \
		log info "Successfully installed docker-machine"
    }

    local CMD=docker-compose
    hash $CMD 2>/dev/null || {
    	log warn docker-compose not available. Attempting to install. 
    	curl -L https://github.com/docker/compose/releases/download/"${DOCKER_COMPOSE}"/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && \
    	chmod +x /usr/local/bin/docker-compose && \
		log info "Successfully installed docker-compose" 	
    }
}

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
function docker_cleanup() {
	# remove all stopped containers
	docker rm $(docker ps -a -q) # Restrict to stuff running from k8s

	# Delete all untagged images	
	docker rmi -f $(docker images | grep "^<none>" | awk '{print $3}')
}

function bootstrap_k8s() {
	[ -z ${K8S_VERSION} ] && K8S_VERSION=1.0
	docker run \
	    --volume=/:/rootfs:ro \
	    --volume=/sys:/sys:ro \
	    --volume=/dev:/dev \
	    --volume=/var/lib/docker/:/var/lib/docker:rw \
	    --volume=/var/lib/kubelet/:/var/lib/kubelet:rw \
	    --volume=/var/run:/var/run:rw \
	    --net=host \
	    --pid=host \
	    --privileged=true \
	    -d \
	    gcr.io/google_containers/hyperkube-amd64:v${K8S_VERSION} \
	    /hyperkube kubelet \
	        --containerized \
	        --hostname-override="127.0.0.1" \
	        --address="0.0.0.0" \
	        --api-servers=http://localhost:8080 \
	        --config=/etc/kubernetes/manifests \
	        --cluster-dns=10.0.0.10 \
	        --cluster-domain=cluster.local \
	        --allow-privileged=true --v=10

}

function switch_docker_cluster() {
	kubectl config set-cluster ${PROJECT_ID} --server=http://localhost:8080
	kubectl config set-context ${PROJECT_ID} --cluster=${PROJECT_ID}
	kubectl config use-context ${PROJECT_ID}
}

