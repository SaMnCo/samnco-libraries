#!/bin/bash
#####################################################################
#
# Git bash library to facilitate development
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

# Check if we are sudoer or not
[ $(bash::lib::is_sudoer) -eq 0 ] && bash::lib::die "You must be root or sudo to run this script"

# function: update_to_latest: updates local folder to latest, including submodules
# 
function git::lib::update_to_latest() {
    git pull origin master 2>/dev/null 1>/dev/null && \
        bash::lib::log info Successfully pulled latest version || \
        bash::lib::die Failed to pull latest version
    git submodule update --init --resursive 2>/dev/null 1>/dev/null && \
        bash::lib::log info Successfully updated all submodules || \
        bash::lib::die Failed to update all submodules
}


