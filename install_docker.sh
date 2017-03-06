#!/bin/bash

#set -x

# global settings
CONFIG_DIR=.
YUM_REPO_PATH="/etc/yum.repos.d"

DOCKER_REPO_SRC_PATH="${CONFIG_DIR}/docker.repo"
DOCKER_REPO_DST_PATH="${YUM_REPO_PATH}/docker.repo"

DC_VERSION="1.11.2"
OS_NAME=$(uname -s)
HW_ARCH=$(uname -m)

DST_BIN_PATH="/usr/local/bin"

DOCKER_COMPOSE_SRC_URL="https://github.com/docker/compose/releases/download/${DC_VERSION}/docker-compose-${OS_NAME}-${HW_ARCH}"
DOCKER_COMPOSE_DST_FILENAME="docker-compose"
DOCKER_COMPOSE_DST_PATH="${DST_BIN_PATH}/${DOCKER_COMPOSE_DST_FILENAME}"

#############
# Functions #
#############
function updatePackages_yumUpdate()
{
    sudo yum -q makecache fast
    sudo yum -q -y update
}
function updatePackages()
{
    echo "-----"
    echo "Updating packages"

    echo " > executing yum update"
    updatePackages_yumUpdate
    
    if [ $? -eq 0 ] ; then
      echo "-----"
      echo "Packages update completed"
    else
      echo "-----"
      echo "Error: packages update failed"
    fi;
}

function installDockerPackage_setDockerRepo()
{
    if [ -f ${DOCKER_REPO_SRC_PATH} ] && [ -d ${YUM_REPO_PATH} ] ; then
      # copy docker.repo inside yum.repos.d
      sudo cp ${DOCKER_REPO_SRC_PATH} ${DOCKER_REPO_DST_PATH}
      sudo chown root:root ${DOCKER_REPO_DST_PATH}
    else
      echo "Error: cannot set docker repository!"
      return 1
    fi;
}
function installDockerPackage_applyFix25741()
{
    # DART fixing docker bug #25741
    # DART this folder should exist prior to install docker
    DOCKER_SELINUX_DIR=/var/lib/docker
    [ -d ${DOCKER_SELINUX_DIR} ] || sudo mkdir -p ${DOCKER_SELINUX_DIR}
    sudo chown root:root ${DOCKER_SELINUX_DIR}
}

function installDockerPackage_installDocker()
{
    # install engine
    echo "-----"
    echo "Installing docker engine"
    sudo yum -q -y install docker-engine

    # show installed version
    echo "> version installed:"
    dockerVersion=$(sudo yum list installed | grep "docker-engine.${HW_ARCH}")
    echo ${dockerVersion}

    # install compose
    echo "-----"
    echo "Installing docker compose"
    echo " > downloading from URL: ${DOCKER_COMPOSE_SRC_URL}"
    curl -L ${DOCKER_COMPOSE_SRC_URL} -o ${DOCKER_COMPOSE_DST_FILENAME}
    echo " > installing into ${DST_BIN_PATH}"
    sudo mv ${DOCKER_COMPOSE_DST_FILENAME} ${DOCKER_COMPOSE_DST_PATH}
    sudo chmod a+x ${DOCKER_COMPOSE_DST_PATH}

    # configure docker
    echo "-----"
    echo "Configuring docker"

    echo " > check the service and start the daemon"
    # enable the service
    dockerEnabled=$(sudo systemctl is-enabled docker.service)
    if [ ${dockerEnabled} == "disabled" ] ; then
        echo " >> enable docker.service"
        sudo systemctl enable docker.service
    else
        echo " >> docker.service already enabled"
    fi;

    # start the daemon
    dockerActive=$(sudo systemctl is-active docker)
    if [ ${dockerActive} == "inactive" ] ; then
        echo " >> start the daemon"
        sudo systemctl start docker
    else
        echo " >> try to restart docker daemon"
        sudo systemctl daemon-reload
        sudo systemctl restart docker
    fi;
}

installDockerPackage() {
    # install docker engine and compose
    echo "-----"
    echo "Adding docker repository to yum"

    # applying docker.repo setting
    installDockerPackage_setDockerRepo

    if [ $? -eq 0 ] ; then
      # DART execute this fix prior to install
      installDockerPackage_applyFix25741
      installDockerPackage_installDocker
    fi;
}

########
# Main #
########

# perform a silent upgrade of the system
updatePackages

# install docker
installDockerPackage

echo "-----"
