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

# Check if we are sudoer or not
[ $(bash::lib::is_sudoer) -eq 0 ] && bash::lib::die "You must be root or sudo to run this script"

# Load Configuration
MYNAME="$(readlink -f "$0")"
MYDIR="$(dirname "${MYNAME}")"
FACILITY=${FACILITY:-"local0"}
LOGTAG=${LOGTAG:-"unknown"}
MIN_LOG_LEVEL=${MIN_LOG_LEVEL:-"debug"}

# charm::lib::self_assessment
# Test if running inside of a charm hook and, if yes, returns the name of the charm. Otherwise returns 0
function charm::lib::self_assessment) {
	[ -z ${JUJU_CONTEXT_ID+x} ] && \
		echo 0 || \
		cat "${JUJU_CHARM_DIR}/metadata.yaml" | grep 'name' | head -n1 | cut -f2 -d' '
}
