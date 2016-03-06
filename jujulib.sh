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

# Load Configuration
MYNAME="$(readlink -f "$0")"
MYDIR="$(dirname "${MYNAME}")"
FACILITY=${FACILITY:-"local0"}
LOGTAG=${LOGTAG:-"unknown"}
MIN_LOG_LEVEL=${MIN_LOG_LEVEL:-"debug"}

BASHLIB="00_bashlib.sh"
find ${MYDIR}/.. -name "${BASHLIB}" -exec source {} 

# Check if we are sudoer or not
[ $(bash::lib::is_sudoer) -eq 0 ] && bash::lib::die "You must be root or sudo to run this script"

# Alias to switch to environment and log
function juju::lib::switchenv() {
    local PROJECT="$1"

    PROJ_EXIST="$(juju list | grep ${PROJECT} | wc -l)"

    if [ "${PROJ_EXIST}" = 0 ]; then
        bash::lib::die "${PROJECT}" environment not set. Please update your Juju environments.yaml file
    fi

    juju switch "${PROJECT}" 1>/dev/null 2>/dev/null \
      && bash::lib::log debug Successfully switched to "${PROJECT}" \
      || bash::lib::log err Could not switch to "${PROJECT}"
}

# Alias to deploy and log for common charms
function juju::lib::deploy() {
    local CHARMNAME="$1"
    shift
    local SERVICENAME="$1"
    shift
    local CONSTRAINTS="$*"

    juju deploy --constraints "${CONSTRAINTS}" "${CHARMNAME}" "${SERVICENAME}" 2>/dev/null \
      && bash::lib::log debug Successfully deployed ${SERVICENAME} \
      || bash::lib::log crit Could not deploy ${SERVICENAME}

    if [ "x${CONSTRAINTS}" != "x" ]; then
      juju set-constraints --service "${SERVICENAME}" "${CONSTRAINTS}" 2>/dev/null \
        && bash::lib::log debug Successfully set constraints \"${CONSTRAINTS}\" for ${SERVICENAME} \
        || bash::lib::log err Could not set constraints for ${SERVICENAME}
    fi
}

# Alias to deploy and log for common charms
function juju::lib::deploy_to() {
    local CHARMNAME="$1"
    shift
    local SERVICENAME="$1"
    shift
    local MACHINEID="$1"

    juju deploy --to "${MACHINEID}" "${CHARMNAME}" "${SERVICENAME}" 2>/dev/null \
      && bash::lib::log debug Successfully deployed ${SERVICENAME} to machine ${MACHINEID} \
      || bash::lib::log crit Could not deploy ${SERVICENAME} to machine ${MACHINEID}
}

# Alias to add a relation
function juju::lib::add_relation() {
    local SERVICE_1="$1"
    shift
    local SERVICE_2="$1"

    juju add-relation "${SERVICE_1}" "${SERVICE_2}" 2>/dev/null \
      && bash::lib::log debug Successfully created relation between ${SERVICE_1} and ${SERVICE_2} \
      || bash::lib::log crit Could not create relation between ${SERVICE_1} and ${SERVICE_2} 
}

# Alias to add unit
function juju::lib::add_unit() {
    local SERVICE="$1"
    shift
    local NEW_UNITS="$1"

    [ "x${NEW_UNITS}" = "x" ] && NEW_UNITS=1

    juju add-unit "${SERVICE}" -n "${NEW_UNITS}" 2>/dev/null \
      && bash::lib::log debug Successfully added ${NEW_UNITS} units of ${SERVICE} \
      || bash::lib::log warn Could not add ${NEW_UNITS} units of ${SERVICE} 
}juju::lib::

# Alias to expose service
function juju::lib::expose() {
    local SERVICE="$1"
    
    juju expose "${SERVICE}" 2>/dev/null \
      && bash::lib::log debug Successfully exposed ${SERVICE} \
      || bash::lib::log warn Could not expose ${SERVICE} 
}

function juju::lib::get_status() {
    local SERVICE="$1"
    juju status ${SERVICE} --format=tabular | grep ${SERVICE} | awk '{ print $2 }' | head -n1
}