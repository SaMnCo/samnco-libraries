#!/bin/bash
#####################################################################
#
# bash command library to facilitate development
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

# source ./00_bashlib.sh

# Check if we are sudoer or not
[ $(bash::lib::is_sudoer) -eq 0 ] && bash::lib::die "You must be root or sudo to run this script"

# Load Configuration
MYNAME="$(readlink -f "$0")"
MYDIR="$(dirname "${MYNAME}")"

FACILITY=${FACILITY:-"local0"}
LOGTAG=${LOGTAG:-"unknown"}
MIN_LOG_LEVEL=${MIN_LOG_LEVEL:-"debug"}

# Test if Google Cloud SDK is installed or installs it silently
# usage ensure_gcloud_or_install
function aws::lib::ensure_awscli_or_install() {
    local CMD=aws
    hash $CMD 2>/dev/null || {
    	bash::lib::ensure_cmd_or_install_package_apt pip python-pip
    	bash::lib::log warn AWS CLI not available. Attempting to install. 
    	pip install --quiet --upgrade aws-cli || bash::lib::die "Could not install AWS CLI"    
    }
}

function aws::lib::ensure_kubeaws_or_install() {
    local CMD=kube-aws
    hash $CMD 2>/dev/null || {
    	bash::lib::ensure_cmd_or_install_package_apt gpg2 gnupg2
    	bash::lib::log warn Kube AWS CLI not available. Attempting to install. 
		case ${OS} in 
			"mac" ) 
				bash::lib::log error TBD
			;;
			"linux" )
				# Need to add clever management of the latest version. Github API has that. 
			   	wget -c -P /tmp https://github.com/coreos/coreos-kubernetes/releases/download/v0.6.1/kube-aws-linux-${ARCH_ALT}.tar.gz && \
		    		cd /tmp && \
		    		tar xfz kube-aws-linux-${ARCH_ALT}.tar.gz && \
		    		mv  linux-amd64/kube-aws /usr/local/bin/ && \
		    		bash::lib::log info "kube-aws now available from the CLI" || \
		    		bash::lib::die Could not install kube-aws
		    ;;
		esac
    }
}

# function aws::lib::validate_creds() {
	
# 	# TBD add management of creds. Test env & presence of ~/.aws/credentials. 
# 	# See https://coreos.com/kubernetes/docs/latest/kubernetes-on-aws.html

# }

function aws::lib::switch_project() {
# Initialize environment
	bash::lib::log debug Switching to selected AWS profile

	# Configure Google Cloud Environment
	export AWS_OPTIONS="--profile ${PROJECT_ID} --output json --region ${REGION} "
}

function aws::lib::switch_k8s_cluster() {
	local CLUSTER="$1"
	# TBD

}

# function aws::lib::read_arn() {
# 	KMS_FILE_${PROJECT_NAME}
# 	cat KMS_${PROJECT_NAME} | jq '.[].Arn' | tr -d '"')"
# }