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

# Discovery of the OS we're running on
OS=` echo \`uname\` | tr '[:upper:]' '[:lower:]'`
KERNEL=`uname -r`
MACH=`uname -m`

if [ "${OS}" == "windowsnt" ]; then
    OS=windows
elif [ "${OS}" == "darwin" ]; then
    OS=mac
else
    OS=`uname`
    if [ "${OS}" = "SunOS" ] ; then
        OS=Solaris
        ARCH=`uname -p`
        OSSTR="${OS} ${REV}(${ARCH} `uname -v`)"
    elif [ "${OS}" = "AIX" ] ; then
        OSSTR="${OS} `oslevel` (`oslevel -r`)"
    elif [ "${OS}" = "Linux" ] ; then
        if [ -f /etc/redhat-release ] ; then
            DISTROBASEDON='RedHat'
            DIST=`cat /etc/redhat-release |sed s/\ release.*//`
            PSEUDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
            REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
        elif [ -f /etc/SuSE-release ] ; then
            DISTROBASEDON='SuSe'
            PSEUDONAME=`cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//`
            REV=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //`
        elif [ -f /etc/mandrake-release ] ; then
            DISTROBASEDON='Mandrake'
            PSEUDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
            REV=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
        elif [ -f /etc/debian_version ] ; then
            DISTROBASEDON='Debian'
            if [ -f /etc/lsb-release ] ; then
                DIST=`cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F=  '{ print $2 }' | tr '[:upper:]' '[:lower:]'`
                PSEUDONAME=`cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F=  '{ print $2 }'`
                REV=`cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }'`
            fi
        fi
        if [ -f /etc/UnitedLinux-release ] ; then
            DIST="${DIST}[`cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//`]"
        fi
        OS=`echo $OS | tr '[:upper:]' '[:lower:]'`
        DISTROBASEDON=`echo $DISTROBASEON | tr '[:upper:]' '[:lower:]'`
        readonly OS
        readonly DIST
        readonly DISTROBASEDON
        readonly PSEUDONAME
        readonly REV
        readonly KERNEL
        readonly MACH
    fi
fi

# Validating I am running on debian-like OS
[ -f /etc/debian_version ] || {
    echo "We are not running on a Debian-like system. Exiting..."
    exit 0
}

# Setting some high level specifics depending on versions
case "$(arch)" in
    "x86_64" | "amd64" )
        ARCH="x86_64"
        ARCH_ALT="amd64"
    ;;
    "ppc64le" | "ppc64el" )
        ARCH="ppc64le"
    ;;
    * )
        echo "Your architecture is not supported. Exiting"
        exit 1
    ;;
esac

case "${PSEUDONAME}" in 
    "precise" )
        # LXC_CMD=""
        APT_CMD="apt-get"
        APT_FORCE="--force-yes"
    ;;
    "trusty" )
        LXC_CMD="$(running-in-container | grep lxc | wc -l)"
        APT_CMD="apt-get"
        APT_FORCE="--force-yes"
    ;;
    "xenial" | "yakkety" )
        LXC_CMD="$(systemd-detect-virt --container | grep lxc | wc -l)"
        APT_CMD="apt"
        APT_FORCE="--allow-downgrades --allow-remove-essential --allow-change-held-packages"
    ;;
    * )
        echo "Your version of Ubuntu is not supported. Exiting"
        exit 1
    ;;
esac

# Load Configuration
MYNAME="$(readlink -f "$0")"
MYDIR="$(dirname "${MYNAME}")"
LOCAL_K8S_VERSION=1.5.1

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

function bash::lib::throw_errors()
{
    set -e
}

function bash::lib::ignore_errors()
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
        (sudo ${APT_CMD} update && sudo ${APT_CMD} install -yqq ${APT_FORCE} ${PKG}) || bash::lib::die "Could not find $PKG"
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

function bash::lib::ensure_cmd_or_install_kubectl() {
    local CMD=kubectl

    [ -z ${K8S_VERSION} ] && K8S_VERSION=${LOCAL_K8S_VERSION}
    hash $CMD 2>/dev/null || {
        bash::lib::log warn $CMD not available. Attempting to install...
        wget curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
        chmod 755 kubectl
        sudo mv kubectl /usr/local/bin/
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

# get_ubuntu_codename: reports the name of the distro (14.04 => Trusty)
function bash::lib::get_ubuntu_codename() {
    echo ${PSEUDONAME}
}

# get_ubuntu_version: get the version of Ubuntu (14.04, 16.04...)
function bash::lib::get_ubuntu_version() {
    echo ${REV}
}

# add_to_library_path: adds a path to the library path
# Usage: add_to_library_path /path/to/add
function bash::lib::add_to_library_path() {
    local ADD_PATH=$1
    local LIB_NAME="$(echo ${ADD_PATH} | cut -f2- -d'/' | tr '/' '_')"
    echo ${ADD_PATH} | sudo tee /etc/ld.so.conf.d/${LIB_NAME}.conf
    sudo ldconfig

    echo "export LD_LIBRARY_PATH='${LD_LIBRARY_PATH}':${ADD_PATH}" | sudo tee /etc/profile.d/${LIB_NAME}.sh
    sudo chmod +x /etc/profile.d/${LIB_NAME}.sh
    /etc/profile.d/${LIB_NAME}.sh
}

# add_to_library_path: adds a path to the library path
# Usage: add_to_library_path /path/to/add
function bash::lib::add_to_path() {
    local ADD_PATH=$1
    local PATH_NAME="$(echo ${ADD_PATH} | cut -f2- -d'/' | tr '/' '_')"
    echo "export PATH='${PATH}':${ADD_PATH}" | sudo tee /etc/profile.d/${PATH_NAME}.sh
    sudo chmod +x /etc/profile.d/${PATH_NAME}.sh
    /etc/profile.d/${PATH_NAME}.sh
}

function bash::lib::init_file_parser() {
    ini="$(<$1)"                # read the file
    ini="${ini//[/\[}"          # escape [
    ini="${ini//]/\]}"          # escape ]
    IFS=$'\n' && ini=( ${ini} ) # convert to line-array
    ini=( ${ini[*]//;*/} )      # remove comments with ;
    ini=( ${ini[*]/\    =/=} )  # remove tabs before =
    ini=( ${ini[*]/=\   /=} )   # remove tabs be =
    ini=( ${ini[*]/\ =\ /=} )   # remove anything with a space around =
    ini=( ${ini[*]/#\\[/\}$'\n'cfg.section.} ) # set section prefix
    ini=( ${ini[*]/%\\]/ \(} )    # convert text2function (1)
    ini=( ${ini[*]/=/=\( } )    # convert item to array
    ini=( ${ini[*]/%/ \)} )     # close array parenthesis
    ini=( ${ini[*]/%\\ \)/ \\} ) # the multiline trick
    ini=( ${ini[*]/%\( \)/\(\) \{} ) # convert text2function (2)
    ini=( ${ini[*]/%\} \)/\}} ) # remove extra parenthesis
    ini[0]="" # remove first element
    ini[${#ini[*]} + 1]='}'    # add the last brace
    eval "$(echo "${ini[*]}")" # eval the result
}

function bash::lib::init_file_writer() {
    IFS=' '$'\n'
    fun="$(declare -F)"
    fun="${fun//declare -f/}"
    for f in $fun; do
        [ "${f#cfg.section}" == "${f}" ] && continue
        item="$(declare -f ${f})"
        item="${item##*\{}"
        item="${item%\}}"
        item="${item//=*;/}"
        vars="${item//=*/}"
        eval $f
        echo "[${f#cfg.section.}]"
        for var in $vars; do
            echo $var=\"${!var}\"
        done
    done
}

#
# based on http://theoldschooldevops.com/2008/02/09/bash-ini-parser/
#

PREFIX="cfg_section_"

function bash::lib::debug_ini {
   return #abort debug
   echo $*
   echo --start--
   echo "${ini[*]}"
   echo --end--
   echo
}

function bash::lib::init_cfg_parser {
   shopt -p extglob &> /dev/null
   CHANGE_EXTGLOB=$?
   if [ $CHANGE_EXTGLOB = 1 ]
   then
      shopt -s extglob
   fi
   ini="$(<$1)"                 # read the file
   ini="${ini//[/\\[}"          # escape [
   bash::lib::debug_ini
   ini="${ini//]/\\]}"          # escape ]
   bash::lib::debug_ini
   IFS=$'\n' && ini=( ${ini} )  # convert to line-array
   bash::lib::debug_ini
   ini=( ${ini[*]//;*/} )       # remove comments with ;
   bash::lib::debug_ini
   ini=( ${ini[*]/#+([[:space:]])/} ) # remove init whitespace
   bash::lib::debug_ini "whitespace around"
   ini=( ${ini[*]/*([[:space:]])=*([[:space:]])/=} ) # remove whitespace around =
   bash::lib::debug_ini
   ini=( ${ini[*]/#\\[/\}$'\n'"$PREFIX"} ) # set section prefix
   bash::lib::debug_ini
   ini=( ${ini[*]/%\\]/ \(} )   # convert text2function (1)
   bash::lib::debug_ini
   ini=( ${ini[*]/=/=\( } )     # convert item to array
   bash::lib::debug_ini
   ini=( ${ini[*]/%/ \)} )      # close array parenthesis
   bash::lib::debug_ini
   ini=( ${ini[*]/%\\ \)/ \\} ) # the multiline trick
   bash::lib::debug_ini
   ini=( ${ini[*]/%\( \)/\(\) \{} ) # convert text2function (2)
   bash::lib::debug_ini
   ini=( ${ini[*]/%\} \)/\}} )  # remove extra parenthesis
   ini=( ${ini[*]/%\{/\{$'\n''bash::lib::init_cfg_unset ${FUNCNAME/#'$PREFIX'}'$'\n'} )  # 'clean previous definition of section 
   bash::lib::debug_ini
   ini[0]=""                    # remove first element
   bash::lib::debug_ini
   ini[${#ini[*]} + 1]='}'      # add the last brace
   bash::lib::debug_ini
   eval "$(echo "${ini[*]}")"   # eval the result
   EVAL_STATUS=$?
   if [ $CHANGE_EXTGLOB = 1 ]
   then
      shopt -u extglob
   fi
   return $EVAL_STATUS
}

function bash::lib::init_cfg_writer {
   SECTION=$1
   OLDIFS="$IFS"
   IFS=' '$'\n'
   if [ -z "$SECTION" ] 
   then
      fun="$(declare -F)"
   else
      fun="$(declare -F $PREFIX$SECTION)"
      if [ -z "$fun" ]
      then
         echo "section $SECTION not found" >2
         exit 1
      fi
   fi
   fun="${fun//declare -f/}"
   for f in $fun; do
      [ "${f#$PREFIX}" == "${f}" ] && continue
      item="$(declare -f ${f})"
      item="${item##*\{}" # remove function definition
      item="${item##*FUNCNAME*$PREFIX\};}" # remove clear section
      item="${item/\}}"  # remove function close
      item="${item%)*}" # remove everything after parenthesis
      item="${item});" # add close parenthesis
      vars=""
      while [ "$item" != "" ]
      do
         newvar="${item%%=*}" # get item name
         vars="$vars $newvar" # add name to collection
         item="${item#*;}" # remove readed line
      done
      eval $f
      echo "[${f#$PREFIX}]" # output section
      for var in $vars; do
         eval 'local length=${#'$var'[*]}' # test if var is an array
         if [ $length == 1 ]
         then
            echo $var=\"${!var}\" #output var
         else 
            echo ";$var is an array" # add comment denoting var is an array
            eval 'echo $var=\"${'$var'[*]}\"' # output array var
         fi
      done
   done
   IFS="$OLDIFS"
}

function bash::lib::init_cfg_unset {
   SECTION=$1
   OLDIFS="$IFS"
   IFS=' '$'\n'
   if [ -z "$SECTION" ] 
   then
      fun="$(declare -F)"
   else
      fun="$(declare -F $PREFIX$SECTION)"
      if [ -z "$fun" ]
      then
         echo "section $SECTION not found" >2
         return
      fi
   fi
   fun="${fun//declare -f/}"
   for f in $fun; do
      [ "${f#$PREFIX}" == "${f}" ] && continue
      item="$(declare -f ${f})"
      item="${item##*\{}" # remove function definition
      item="${item##*FUNCNAME*$PREFIX\};}" # remove clear section
      item="${item/\}}"  # remove function close
      item="${item%)*}" # remove everything after parenthesis
      item="${item});" # add close parenthesis
      vars=""
      while [ "$item" != "" ]
      do
         newvar="${item%%=*}" # get item name
         vars="$vars $newvar" # add name to collection
         item="${item#*;}" # remove readed line
      done
      for var in $vars; do
         unset $var
      done
   done
   IFS="$OLDIFS"
}

function bash::lib::init_cfg_clear {
   SECTION=$1
   OLDIFS="$IFS"
   IFS=' '$'\n'
   if [ -z "$SECTION" ] 
   then
      fun="$(declare -F)"
   else
      fun="$(declare -F $PREFIX$SECTION)"
      if [ -z "$fun" ]
      then
         echo "section $SECTION not found" >2
         exit 1
      fi
   fi
   fun="${fun//declare -f/}"
   for f in $fun; do
      [ "${f#$PREFIX}" == "${f}" ] && continue
      unset -f ${f}
   done
   IFS="$OLDIFS"
}

function bash::lib::init_cfg_update {
   SECTION=$1
   VAR=$2
   OLDIFS="$IFS"
   IFS=' '$'\n'
   fun="$(declare -F $PREFIX$SECTION)"
   if [ -z "$fun" ]
   then
      echo "section $SECTION not found" >2
      exit 1
   fi
   fun="${fun//declare -f/}"
   item="$(declare -f ${fun})"
   #item="${item##* $VAR=*}" # remove var declaration
   item="${item/\}}"  # remove function close
   item="${item}
    $VAR=(${!VAR})
   "
   item="${item}
   }" # close function again
   
   eval "function $item" 
}

# based on https://gist.github.com/pkuczynski/8665367

function bash::lib::parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

# Test Script: 
# #!/bin/sh

# # include parse_yaml function
# . parse_yaml.sh

# # read yaml file
# eval $(parse_yaml zconfig.yml "config_")

# # access yaml content
# echo $config_development_database

# with file: 

# development:
#   adapter: mysql2
#   encoding: utf8
#   database: my_database
#   username: root
#   password:

# Check if we are sudoer or not
[ $(bash::lib::is_sudoer) -eq 0 ] && bash::lib::die "You must be root or sudo to run this script"

