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

# Check if we are sudoer or not
[ $(bash::lib::is_sudoer) -eq 0 ] && bash::lib::die "You must be root or sudo to run this script"

# Test if Google Cloud SDK is installed or installs it silently
# usage ensure_gcloud_or_install
function gce::lib::ensure_gcloud_or_install() {
    local CMD=gcloud
    hash $CMD 2>/dev/null || {
    	bash::lib::ensure_cmd_or_install_package_apt curl curl
    	bash::lib::log warn Google Cloud SDK not available. Attempting to install. 
    	export CLOUDSDK_CORE_DISABLE_PROMPTS=1
    	(curl https://sdk.cloud.google.com | bash) || bash::lib::die "Could not install Google Cloud SDK"    }
}

function gce::lib::switch_project() {
# Initialize environment
	bash::lib::log debug Updating Google Cloud SDK components
	gcloud components update -q 2>/dev/null

	# Configure Google Cloud Environment
	gcloud config set project $PROJECT_ID
	gcloud config set compute/zone $ZONE
	gcloud config set compute/region $REGION	
}

function gce::lib::switch_gke_cluster() {
	local CLUSTER="$1"
	# Use App Cluster
	# Use this cluster & set creds for k8s
    gcloud config set container/cluster -q "${CLUSTER}" \
        && log info Selected ${CLUSTER} as current GKE cluster \
        || die Could not switch current GKE cluster
    gcloud container clusters get-credentials  -q "${CLUSTER}" \
        && log info Set kubectl credentials for ${CLUSTER} \
        || die Could not set kubectl credentials for ${CLUSTER}
}

# Create a volume in Google Cloud based on a description json file
# usage create_gcloud_disk <path to volume file>
function gce::lib::create_gcloud_disk() {
	local GCLOUDCMD=""

	# Validating Disk Name
	DISKNAME="$(basename $(readlink -f "$1"))"
	SHORTDISKNAME="$(echo ${DISKNAME} | cut -f1 -d'.')"
	DISKDIR="$(dirname $(readlink -f "$1"))"
	[ ! -f "${DISKDIR}/${DISKNAME}" ] && bash::lib::die "Volume JSON file does not exist"
	DISKNAME2=$(jq '.name' ${DISKDIR}/${DISKNAME} | tr -d '"')
	# [ "${SHORTDISKNAME}" != "${DISKNAME2}" ] && bash::lib::die "Disk name and file name do not match"
	GCLOUDCMD="${GCLOUDCMD} ${DISKNAME2}"

	# Checking Zone for the disk
	DISKZONE=$(jq '.zone' ${DISKDIR}/${DISKNAME} | tr -d '"')
	case "x${DISKZONE}" in 
		"x${ZONE}" )
			bash::lib::log debug using ${ZONE} as disk creation zone
		;;
		"x" )
			DISKZONE="${ZONE}"
			bash::lib::log debug using ${ZONE} as disk creation zone
		;;
		* )
			NBZONES=$(grep ${DISKZONE} "${MYDIR}/../etc/gce-valid-zones" | wc -l)
			if [ "${NBZONES}" = "0" ] ; then
				bash::lib::die Selected zone does not exist. Please modify "$1"
			fi
			bash::lib::log warn Disk Zone and Project Zone do not match
		;;
	esac
	GCLOUDCMD="${GCLOUDCMD} --zone ${DISKZONE}"


	# Validating Disk Type
	DISKTYPE=$(jq '.type' ${DISKDIR}/${DISKNAME} | tr -d '"')
	[ "x${DISKTYPE}" = "x" ] && DISKTYPE="pd-standard"
	DISKTYPEZONE=$(grep ${DISKZONE} "${MYDIR}/../etc/gce-valid-disk-options" | grep "${DISKTYPE}" | wc -l)
	if [ "${DISKTYPEZONE}" = "0" ] ; then
		bash::lib::die Selected type does not exist in ${DISKZONE}. Please modify "$1"
	fi
	bash::lib::log debug "Using ${DISKTYPE} in ${DISKZONE} for disk ${DISKNAME}"

	case "${DISKTYPE}" in 
		"local-ssd" )
			bash::lib::log debug using ${DISKTYPE} for disk ${DISKNAME}
		;;
		"pd-ssd" )
			bash::lib::log debug using ${DISKTYPE} for disk ${DISKNAME}
		;;
		"pd-standard" )
			bash::lib::log debug using ${DISKTYPE} for disk ${DISKNAME}
		;;
		* )
			bash::lib::die Disk Type ${DISKTYPE} is not managed. Please modify "$1"
		;;
	esac
	GCLOUDCMD="${GCLOUDCMD} --type ${DISKTYPE}"

	# Validating Disk Size
	DISKSIZE=$(jq '.size' ${DISKDIR}/${DISKNAME} | tr -d '"')
	[ "x${DISKSIZE}" = "x" ] && DISKSIZE="10GB"
	INTDISKSIZE=$(echo ${DISKSIZE} | tr -d "GB")
	MINDISKSIZE=$(grep ${DISKZONE} "${MYDIR}/../etc/gce-valid-disk-options" | grep "${DISKTYPE}" | cut -f3 -d";" | cut -f1 -d"-" | tr -d "GB")
	MAXDISKSIZE=$(grep ${DISKZONE} "${MYDIR}/../etc/gce-valid-disk-options" | grep "${DISKTYPE}" | cut -f3 -d";" | cut -f2 -d"-" | tr -d "GB")
	if [[ ${INTDISKSIZE} -ge ${MINDISKSIZE} &&  ${INTDISKSIZE} -le ${MAXDISKSIZE} ]] ; then
		bash::lib::log debug "Disk size ${DISKSIZE} is valid"
	else
		bash::lib::die Invalid disk size ${DISKSIZE} in ${DISKZONE} and ${DISKTYPE}. Please modify "$1"
	fi
	GCLOUDCMD="${GCLOUDCMD} --size ${DISKSIZE}"

	# Description is a text. No need to validate
	DISKDESCRIPTION="$(jq '.description' ${DISKDIR}/${DISKNAME})"
	# GCLOUDCMD="${GCLOUDCMD} --description \"${DISKDESCRIPTION}\""

	#
	# Disk Image is not managed yet
	#
	# Validating Disk Image
	#DISKIMAGE=$(jq '.image' ${DISKDIR}/${DISKNAME} | tr -d '"')
	#DISKIMAGELIST=$(grep ${DISKIMAGE} "${MYDIR}/../etc/gce-valid-images" | wc -l)
	#if [ "${DISKIMAGELIST}" = "0" ] ; then
	#	bash::lib::die Selected image does not exist. Please modify "$1"
	#fi
	#bash::lib::log debug "Using ${DISKIMAGE} for disk ${DISKNAME}"

	#
	# Disk Image Project is not managed yet
	#
	#DISKIMAGEPROJECT=$(jq '.image-project' ${DISKDIR}/${DISKNAME} | tr -d '"')

	#
	# Source Snapshot is not managed yet
	#
	#DISKSOURCESNAPSHOT=$(jq '.source-snapshot' ${DISKDIR}/${DISKNAME} | tr -d '"')

	# Finally running creation command
	gcloud compute disks create ${GCLOUDCMD} \
		1>/dev/null 2>/dev/null \
		&& bash::lib::log info Successfully created disk ${DISKNAME} \
		|| bash::lib::die Could not create disk ${DISKNAME}. Exiting. 
}

