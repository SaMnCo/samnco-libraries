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

# Set of commands to emulate try / catch in bash
# usage described on http://stackoverflow.com/questions/22009364/is-there-a-try-catch-command-in-bash
function bash::lib::try()
{
    [[ $- = *e* ]]; SAVED_OPT_E=$?
    set +e
}

function bash::lib::throw()
{
    exit $1
}

function bash::lib::catch()
{
    export EX_CODE=$?
    (( $SAVED_OPT_E )) && set +e
    return $EX_CODE
}

function bash::lib::throwErrors()
{
    set -e
}

function bash::lib::ignoreErrors()
{
    set +e
}

# Log to syslog and echo log line
# usage bash::lib::log <syslog level> <log line>
# See https://en.wikipedia.org/wiki/Syslog for more information
function bash::lib::log() {
    local LOGLEVEL=$1
    if [ "x${LOGLEVEL}" = "x" ] ; then
        LOGLEVEL=${MIN_LOG_LEVEL}
        echo "["`date`"] ["${LOGTAG}"] ["${FACILITY}.warn"] : "Missing Log Level for ${LOGLINE}        
        logger -t ${LOGTAG} -p ${FACILITY}.warn Missing Log Level for ${LOGLINE} 2>/dev/null
    fi        
    shift
    local LOGLINE="$*"
    local MAX_LOG_INT=$(grep ${MIN_LOG_LEVEL} "${MYDIR}/../etc/syslog-levels" | cut -f1 -d",")
    local CURRENT_LOG_INT=$(grep ${LOGLEVEL} "${MYDIR}/../etc/syslog-levels" | cut -f1 -d",")
    if [ ${MAX_LOG_INT} -ge ${CURRENT_LOG_INT} ]; then
        echo "["`date`"] ["${LOGTAG}"] ["${FACILITY}.${LOGLEVEL}"] : "${LOGLINE}
        logger -t ${LOGTAG} -p ${FACILITY}.${LOGLEVEL} ${LOGLINE} 2>/dev/null
    fi
}

# Dies elegantly with an error log
# usage bash::lib::die <log line>
# See https://en.wikipedia.org/wiki/Syslog for more information
function bash::lib::die() {
	local LOGLINE="$*"
	bash::lib::log err ${LOGLINE}. Exiting
	exit 0
}

# ensure_cmd_or_install_package_apt: Test if command is available or install matching package
# usage ensure_cmd_or_install_package_apt <cmd name> <pkg name>
function bash::lib::ensure_cmd_or_install_package_apt() {
    local CMD=$1
    shift
    local PKG=$*
    hash $CMD 2>/dev/null || { 
    	bash::lib::log warn $CMD not available. Attempting to install $PKG
    	(sudo apt-get update && sudo apt-get install -yqq ${PKG}) || bash::lib::die "Could not find $PKG"
    }
}

# ensure_cmd_or_install_from_curl: Test if command is available or install from URL
# usage ensure_cmd_or_install_from_curl <cmd name> <URL>
function bash::lib::ensure_cmd_or_install_from_curl() {
    local CMD=$1
    shift
    local URL="$1"
    hash $CMD 2>/dev/null || { 
    	bash::lib::ensure_cmd_or_install_package_apt curl curl
    	bash::lib::log warn ${CMD} not available. Attempting to install from ${URL}
    	curl -sL "${URL}" --output "${CMD}" \
    		&& chmod 755 "${CMD}" \
    		&& sudo mv "${CMD}" /usr/local/bin/ \
    		|| bash::lib::die "Could not find $PKG"
    }
}

function bash::lib::ensure_cmd_or_install_package_npm() {
    local CMD=$1
    shift
    local PKG=$*
	bash::lib::ensure_cmd_or_install_package_apt npm nodejs npm

    hash $CMD 2>/dev/null || { 
    	bash::lib::log warn $CMD not available. Attempting to install $PKG via npm
    	sudo npm install -f -q -y -g "${PKG}" || bash::lib::die "Could not find $PKG"
    }
}

# Test is a user is sudoer or not. echos 0 if no, and 1 if no. 
function bash::lib::is_sudoer() {
    CAN_RUN_SUDO=$(sudo -n uptime 2>&1|grep "load"|wc -l)
    if [ ${CAN_RUN_SUDO} -gt 0 ]
    then
        echo 1
    else
        echo 0
    fi
}
