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

# Load Configuration
MYNAME="$(readlink -f "$0")"
MYDIR="$(dirname "${MYNAME}")"
MYLIB="${MYDIR}/../lib/bashlib.sh"

for file in "${MYLIB}" ; do
	[ -f ${file} ] && source ${file} || { 
		echo "Could not find required file. Exiting..."
		exit 0
	}
done 

# Alias to switch to environment and log
function switchenv() {
    local PROJECT="$1"

    PROJ_EXIST="$(juju list | grep ${PROJECT} | wc -l)"

    if [ "${PROJ_EXIST}" = 0 ]; then
        die "${PROJECT}" environment not set. Please update your Juju environments.yaml file
    fi

    juju switch "${PROJECT}" 1>/dev/null 2>/dev/null \
      && log debug Successfully switched to "${PROJECT}" \
      || log err Could not switch to "${PROJECT}"
}

# Alias to deploy and log for common charms
function deploy() {
    local CHARMNAME="$1"
    shift
    local SERVICENAME="$1"
    shift
    local CONSTRAINTS="$*"

    juju deploy --constraints "${CONSTRAINTS}" "${CHARMNAME}" "${SERVICENAME}" 2>/dev/null \
      && log debug Successfully deployed ${SERVICENAME} \
      || log crit Could not deploy ${SERVICENAME}

    if [ "x${CONSTRAINTS}" != "x" ]; then
      juju set-constraints --service "${SERVICENAME}" "${CONSTRAINTS}" 2>/dev/null \
        && log debug Successfully set constraints \"${CONSTRAINTS}\" for ${SERVICENAME} \
        || log err Could not set constraints for ${SERVICENAME}
    fi
}

# Alias to deploy and log for common charms
function deploy-to() {
    local CHARMNAME="$1"
    shift
    local SERVICENAME="$1"
    shift
    local MACHINEID="$1"

    juju deploy --to "${MACHINEID}" "${CHARMNAME}" "${SERVICENAME}" 2>/dev/null \
      && log debug Successfully deployed ${SERVICENAME} to machine ${MACHINEID} \
      || log crit Could not deploy ${SERVICENAME} to machine ${MACHINEID}
}

# Alias to add a relation
function add-relation() {
    local SERVICE_1="$1"
    shift
    local SERVICE_2="$1"

    juju add-relation "${SERVICE_1}" "${SERVICE_2}" 2>/dev/null \
      && log debug Successfully created relation between ${SERVICE_1} and ${SERVICE_2} \
      || log crit Could not create relation between ${SERVICE_1} and ${SERVICE_2} 
}

# Alias to add unit
function add-unit() {
    local SERVICE="$1"
    shift
    local NEW_UNITS="$1"

    [ "x${NEW_UNITS}" = "x" ] && NEW_UNITS=1

    juju add-unit "${SERVICE}" -n "${NEW_UNITS}" 2>/dev/null \
      && log debug Successfully added ${NEW_UNITS} units of ${SERVICE} \
      || log warn Could not add ${NEW_UNITS} units of ${SERVICE} 
}

# Alias to expose service
function expose() {
    local SERVICE="$1"
    
    juju expose "${SERVICE}" 2>/dev/null \
      && log debug Successfully exposed ${SERVICE} \
      || log warn Could not expose ${SERVICE} 
}

function get-status() {
    local SERVICE="$1"
    juju status ${SERVICE} --format=tabular | grep ${SERVICE} | awk '{ print $2 }' | head -n1
}