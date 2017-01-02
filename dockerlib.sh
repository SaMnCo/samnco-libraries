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
DOCKER_KEY="58118E89F3A912897C070ADBF76221572C52609D"
DOCKER_COMPOSE="1.8.1"
DOCKER_MACHINE="0.8.2"

FACILITY=${FACILITY:-"local0"}
LOGTAG=${LOGTAG:-"unknown"}
MIN_LOG_LEVEL=${MIN_LOG_LEVEL:-"debug"}

# Check if we are sudoer or not
[ $(bash::lib::is_sudoer) -eq 0 ] && bash::lib::die "You must be root or sudo to run this script"

UBUNTU_CODENAME="$(bash::lib::get_ubuntu_codename)"

case ${UBUNTU_CODENAME} in
	precise )
		bash::lib::log warn This requires a reboot. Please press [Yn] and [ENTER] to continue
		read NEXT
		case ${NEXT} in 
			Y | y )
				sudo ${APT_CMD} update -qq && \
				sudo ${APT_CMD} install -yqq ${APT_FORCE} \
					apparmor \
					linux-image-extra-$(uname -r) \
					linux-image-generic-lts-trusty \
					linux-headers-generic-lts-trusty \
				bash::lib::log warn Now rebooting machine. Please restart process afterward
				sudo reboot now
			;;
			* )
			bash::lib::die Aborting. Nothing installed. 
			;;
		esac
	;;
	trusty )
		bash::lib::log debug Installing dependencies for ${NEXT}
		sudo ${APT_CMD} update -qq && \
		sudo ${APT_CMD} install -yqq ${APT_FORCE} \
			apparmor \
			linux-image-extra-$(uname -r)
	;;
	wily )
		bash::lib::log debug Installing dependencies for ${NEXT}
		sudo ${APT_CMD} update -qq && \
		sudo ${APT_CMD} install -yqq ${APT_FORCE} \
			apparmor \
			linux-image-extra-$(uname -r)
	;;
	* )
	;;
esac		

# Test if Docker is installed or installs it silently
# usage ensure_gcloud_or_install
function docker::lib::ensure_docker_or_install() {
    local CMD=docker
    hash $CMD 2>/dev/null || {
    	bash::lib::ensure_cmd_or_install_package_apt curl curl
    	bash::lib::log warn Docker not available. Attempting to install. 
    	sudo ${APT_CMD} update -qq && \
    	sudo ${APT_CMD} install -yqq apt-transport-https ca-certificates linux-image-extra-$(uname -r)
    	sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "${DOCKER_KEY}"
    	echo "deb https://apt.dockerproject.org/repo ubuntu-${UBUNTU_CODENAME} main" > /etc/apt/sources.list.d/docker.list 
    	sudo ${APT_CMD} update -qq && \
    	sudo ${APT_CMD} install -yqq docker-engine docker.io docker-compose && \
    	sudo groupadd -f docker && \
    	sudo usermod -aG docker ${USER} && \
    	# newgrp ${USER}
    	bash::lib::log info "Successfully installed docker-engine" || \
    	bash::lib::die "Could not install docker-engine"
    }

  #   local CMD=docker-machine
  #   hash $CMD 2>/dev/null || {
  #   	bash::lib::log warn docker-machine not available. Attempting to install. 
  #   	curl -L https://github.com/docker/machine/releases/download/v"${DOCKER_MACHINE}"/docker-machine-`uname -s`-`uname -m` > /tmp/docker-machine && \
  #   	sudo mv /tmp/docker-machine /usr/local/bin/docker-machine && \
		# sudo chmod +x /usr/local/bin/docker-machine && \
		# bash::lib::log info "Successfully installed docker-machine" || \
		# bash::lib::die "Could not install docker-machine"
  #   }

  #   local CMD=docker-compose
  #   hash $CMD 2>/dev/null || {
  #   	bash::lib::log warn docker-compose not available. Attempting to install. 
  #   	curl -L https://github.com/docker/compose/releases/download/"${DOCKER_COMPOSE}"/docker-compose-`uname -s`-`uname -m` > /tmp/docker-compose && \
  #   	sudo mv /tmp/docker-compose /usr/local/bin/docker-compose && \
  #   	sudo chmod +x /usr/local/bin/docker-compose && \
		# bash::lib::log info "Successfully installed docker-compose" || \
		# bash::lib::die "Could not install docker-compose"
  #   }
}

# add_auth: adds the content of a dockercfg file (from quay.io)
#   to the system dockerfile
# usage add_auth <src_dockercfg> <target_dockercfg>
function docker::lib::add_auth() {
    local SOURCE=$1
    shift
    local TARGET=$1
    bash::lib::log crit This feature is not implemented yet
}

# docker_cleanup: deletes all stopped containers and untagged images
#	from the local system
function docker::lib::docker_cleanup() {
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

# docker::lib::bootstrap_k8s : bootstraps a local Kubernets cluster
# Usage: docker::lib::bootstrap_k8s
function docker::lib::bootstrap_k8s() {
	[ -z ${K8S_VERSION} ] && K8S_VERSION=1.1.3
	[ -z ${ETCD_VERSION} ] && ETCD_VERSION=2.0.12
	sudo docker run \
		--net=host \
		-d \
		gcr.io/google_containers/etcd:${ETCD_VERSION} \
		/usr/local/bin/etcd \
			--addr=127.0.0.1:4001 \
			--bind-addr=0.0.0.0:4001 \
			--data-dir=/var/etcd/data && \
	sudo docker run \
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
	    gcr.io/google_containers/hyperkube:v${K8S_VERSION} \
	    /hyperkube kubelet \
	        --containerized \
	        --hostname-override="127.0.0.1" \
	        --address="0.0.0.0" \
	        --api-servers=http://localhost:8080 \
	        --config=/etc/kubernetes/manifests \
	        --cluster-dns=10.0.0.10 \
	        --cluster-domain=cluster.local \
	        --allow-privileged=true --v=10 && \
	sudo docker run \
		-d \
		--net=host \
		--privileged \
		gcr.io/google_containers/hyperkube:v${K8S_VERSION} \
		/hyperkube proxy \
			--master=http://127.0.0.1:8080 \
			--v=2 && \
	bash::lib::log info Successfully bootstrapped k8s locally. You can now use kubectl || \
	bash::lib::die "Could not bootstrap k8s. Please investigate log files"

}

# Build image for nodejs container locally
# Usage: build_node_project path/to/nodejs/project/folder
# Notes: 
#   - This assumes a subfolder containers the Dockerfiles. 
# 	- This subfolder is a submodule using https://github.com/SaMnCo/node-dockerfiles
function docker::lib::build_node_project() {
	local PROJECT_FOLDER="$1"

    [ -f "${PROJECT_FOLDER}/package.json" ] || bash::lib::die Could not locate package.json for ${PROJECT_FOLDER}
    
	local DOCKER_NAME=$(cat "${PROJECT_FOLDER}/package.json" | jq '.name' | tr -d '"')
	local DOCKER_VERSION=$(cat "${PROJECT_FOLDER}/package.json" | jq '.version' | tr -d '"')

	bash::lib::log debug Building latest Docker image for ${DOCKER_NAME}

	[ -z ${NPM_TOKEN} ] && \
		bash::lib::die "NPM_TOKEN not set. Cannot download from private repositories"

	find ${PROJECT_FOLDER} -name ".npmrc" -exec cp -f {} ${PROJECT_FOLDER}/ \;
	
	docker build \
		--quiet \
		--rm \
		--build-arg NPM_TOKEN=${NPM_TOKEN} \
		-f "$(find "${PROJECT_FOLDER}" -name Dockerfile.${DEFAULT_OS}.${DEFAULT_NODE_VERSION})" \
		-t ${PROJECT_ID}/${DOCKER_NAME}:${DEFAULT_OS}-${DOCKER_VERSION} \
		"${PROJECT_FOLDER}" 2>/dev/null 1>/dev/null && \
		rm -f "${PROJECT_FOLDER}/.npmrc" && \
	bash::lib::log info Successfully build image for ${DOCKER_NAME} || \
	bash::lib::die Could not build image for ${DOCKER_NAME}
}

function docker::lib::build_project() {
    local PROJECT_FOLDER="$1"

    [ -f "${PROJECT_FOLDER}/package.json" ] || bash::lib::die Could not locate package.json for ${PROJECT_FOLDER}
    
    local DOCKER_NAME=$(cat "${PROJECT_FOLDER}/package.json" | jq '.name' | tr -d '"')
    local DOCKER_VERSION=$(cat "${PROJECT_FOLDER}/package.json" | jq '.version' | tr -d '"')

    bash::lib::log debug Building latest Docker image for ${DOCKER_NAME}

    docker build \
        --quiet \
        --rm \
        -f "$(find "${PROJECT_FOLDER}" -name Dockerfile)" \
        -t ${PROJECT_ID}/${DOCKER_NAME}:${DEFAULT_OS}-${DOCKER_VERSION} \
        "${PROJECT_FOLDER}" 2>/dev/null 1>/dev/null && \
    bash::lib::log info Successfully build image for ${DOCKER_NAME} || \
    bash::lib::die Could not build image for ${DOCKER_NAME}
}

# docker::lib::push_to_gke_registry: Adds a tag to push to GKE then pushes. 
# Usage: docker::lib::add_tag_for_gke <image/name:version>
# Notes: 
# 	- will use the DEFAULT_REGISTRY set in configuration file 
# 	- will use the PROJECT_ID set in configuration file
function docker::lib::push_to_gke_registry() {
	local ORIGIN="$1"

	docker tag -f \
		"${ORIGIN}" \
		"${DEFAULT_REGISTRY}/${ORIGIN}" 2>/dev/null 1>/dev/null && \
	bash::lib::log info Successfully tagged image ${ORIGIN} for ${DEFAULT_REGISTRY} || \
	bash::lib::die Could not tag image ${ORIGIN} for ${DEFAULT_REGISTRY}

	gcloud docker push "${DEFAULT_REGISTRY}/${ORIGIN}" 2>/dev/null 1>/dev/null && \
	bash::lib::log info Successfully pushed image ${ORIGIN} to ${DEFAULT_REGISTRY} || \
	bash::lib::die Could not push image ${ORIGIN} to ${DEFAULT_REGISTRY}

	#docker rmi -f "${DEFAULT_REGISTRY}/${ORIGIN}" 2>/dev/null 1>/dev/null && \
	#bash::lib::log info Successfully deleted "${DEFAULT_REGISTRY}/${ORIGIN}" || \
	#bash::lib::die Could not delete "${DEFAULT_REGISTRY}/${ORIGIN}"
}

# function switch_docker_cluster() {
# 	kubectl config set-cluster ${PROJECT_ID} --server=http://localhost:8080
# 	kubectl config set-context ${PROJECT_ID} --cluster=${PROJECT_ID}
# 	kubectl config use-context ${PROJECT_ID}
# }

