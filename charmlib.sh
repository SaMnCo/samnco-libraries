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
function charm::lib::self_assessment() {
	[ -d /var/lib/juju/agents ] || exit 1
	for FILE in $(find "/var/lib/juju/agents" -name "metadata.yaml")
	do
		CHARM+=" $(cat "${FILE}" | grep 'name' | head -n1 | cut -f2 -d' ')" 
	done
	echo "${CHARM}" | sort | uniq
}

function charm::lib::get_templates() {
	local INSTALL_DIR="$1"

	[ -d "${INSTALL_DIR}" ] && { 
		cd "${INSTALL_DIR}"
		git pull --quiet --force origin master
	} || {
		git clone --quiet --recursive https://github.com/SaMnCo/ops-templates.git "${INSTALL_DIR}"
	}
}

function charm::lib::find_roles() {
    for TARGET in $(charm::lib::self_assessment)
    do
        case "${CHARM}" in 
            ceilometer | cinder | glance | heat | horizon | keystone | neutron* | nova* | openstack-dashboard )
                juju-log "Configuring ${SOFTWARE_NAME} for ${TARGET} (OpenStack)"
                TARGET_LIST+=" ${TARGET} openstack dmesg"
            ;;
            ceph* )
                juju-log "Configuring ${SOFTWARE_NAME} for ${TARGET} (Ceph Storage)"
                TARGET_LIST+=" ${TARGET} dmesg ceph-global"
            ;;
            * )
                juju-log "Configuring ${SOFTWARE_NAME} for ${TARGET} (Generic Solution)"
                TARGET_LIST+=" ${TARGET}"
            ;;
        esac
    done

    echo "${TARGET_LIST}" | sort | uniq 
}

function charm::lib::who_am_i() {
	cat "${JUJU_CHARM_DIR}/metadata.yaml" | grep 'name' | head -n1 | cut -f2 -d' '
}
