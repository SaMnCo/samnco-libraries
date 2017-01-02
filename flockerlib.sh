# #!/bin/bash
# #####################################################################
# #
# # Docker bash library to facilitate development
# #
# # Notes: 
# # 
# # Maintainer: Samuel Cozannet <samnco@gmail.com>
# #
# #####################################################################

# # Validating I am running on debian-like OS
# [ -f /etc/debian_version ] || {
#     echo "We are not running on a Debian-like system. Exiting..."
#     exit 0
# }

# # Load Configuration
# MYNAME="$(readlink -f "$0")"
# MYDIR="$(dirname "${MYNAME}")"
# DOCKER_KEY="58118E89F3A912897C070ADBF76221572C52609D"
# DOCKER_COMPOSE="1.6.2"
# DOCKER_MACHINE="0.6.0"

# FACILITY=${FACILITY:-"local0"}
# LOGTAG=${LOGTAG:-"unknown"}
# MIN_LOG_LEVEL=${MIN_LOG_LEVEL:-"debug"}

# # Check if we are sudoer or not
# [ $(bash::lib::is_sudoer) -eq 0 ] && bash::lib::die "You must be root or sudo to run this script"

# UBUNTU_CODENAME="$(bash::lib::get_ubuntu_codename)"

# hash docker::lib::ensure_docker_or_install 2>/dev/null || {
# 	find "${MYDIR}" -name "dockerlib.sh" -exec source {} \;
# }

# # Test if Flocker is installed locally or installs it silently
# # usage ensure_flocker_or_install
# function flocker::lib::ensure_flocker_or_install() {
#     local CMD=uft-flocker-install
#     local URL="https://raw.githubusercontent.com/ClusterHQ/unofficial-flocker-tools/master/go.sh"
#     hash $CMD 2>/dev/null || {
#     	bash::lib::ensure_cmd_or_install_package_apt curl curl
#     	bash::lib::log warn Flocker not available. Attempting to install. 
#     	sudo ${APT_CMD} update -qq && \
#     	sudo ${APT_CMD} upgrade -yqq
#     	curl -sSL "${URL}" | sh
#     	bash::lib::log info "Successfully installed docker-engine" || \
#     	bash::lib::die "Could not install docker-engine"
#     }
# }

