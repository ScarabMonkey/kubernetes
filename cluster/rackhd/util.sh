#!/bin/bash

# Copyright 2014 The Kubernetes Authors All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script contains skeletons of helper functions that each provider hosting
# Kubernetes must implement to use cluster/kube-*.sh scripts.
# It sets KUBERNETES_PROVIDER to its default value (gce) if it is unset, and
# then sources cluster/${KUBERNETES_PROVIDER}/util.sh.

# exit on any error
set -e

SSH_OPTS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=ERROR"

# Use the config file specified in $KUBE_CONFIG_FILE, or default to
# config-default.sh.
readonly ROOT=$(dirname "${BASH_SOURCE}")
source "${ROOT}/${KUBE_CONFIG_FILE:-"config-default.sh"}"
source "${KUBE_ROOT}/cluster/common.sh"

# Directory to be used for master and node provisioning.
KUBE_TEMP="~/kube_temp"

# Must ensure that the following ENV vars are set
function detect-master {
	KUBE_MASTER=$MASTER
	KUBE_MASTER_IP=${MASTER#*@}
	echo "KUBE_MASTER_IP: $KUBE_MASTER_IP" 1>&2
	echo "KUBE_MASTER: $KUBE_MASTER" 1>&2
}

# Get node names if they are not static.
#function detect-node-names {
#	echo "NODE_NAMES: [${NODE_NAMES[*]}]" 1>&2
#}

# Get node IP addresses and store in KUBE_NODE_IP_ADDRESSES[]
function detect-nodes {
	KUBE_NODE_IP_ADDRESSES=()
	for node in ${NODES}; do
		KUBE_NODE_IP_ADDRESSES+=("${node#*@}")
	done
	echo "KUBE_NODE_IP_ADDRESSES: [${KUBE_NODE_IP_ADDRESSES[*]}]" 1>&2
}

# Verify prereqs on host machine
function verify-prereqs {
  # need rackhdcli
  which "rackhdcli" >/dev/null || {
    echo "Can't find rackhdcli in PATH, please install and retry."
    echo ""
    echo "    go install github.com/codenrhoden/rackhcli/rackhdcli"
    echo ""
    exit 1
  }

  local rc
  rc=0
  ssh-add -L 1> /dev/null 2> /dev/null || rc="$?"
  # "Could not open a connection to your authentication agent."
  if [[ "${rc}" -eq 2 ]]; then
    eval "$(ssh-agent)" > /dev/null
    trap-add "kill ${SSH_AGENT_PID}" EXIT
  fi
  rc=0
  ssh-add -L 1> /dev/null 2> /dev/null || rc="$?"
  # "The agent has no identities."
  if [[ "${rc}" -eq 1 ]]; then
    # Try adding one of the default identities, with or without passphrase.
    ssh-add || true
  fi
  rc=0
  # Expect at least one identity to be available.
  if ! ssh-add -L 1> /dev/null 2> /dev/null; then
    echo "Could not find or add an SSH identity."
    echo "Please start ssh-agent, add your identity, and retry."
    exit 1
  fi
}

# Validate a kubernetes cluster
function validate-cluster {
	# by default call the generic validate-cluster.sh script, customizable by
	# any cluster provider if this does not fit.
  set +e
  "${KUBE_ROOT}/cluster/validate-cluster.sh"
  if [[ "$?" -ne "0" ]]; then
    troubleshoot-master
    for node in ${NODES}; do
      troubleshoot-node ${node}
    done
    exit 1
  fi
  set -e
}

function troubleshoot-master() {
  # Troubleshooting on master if all required daemons are active.
  echo "[INFO] Troubleshooting on master ${MASTER}"
  local -a required_daemon=("kube-apiserver" "kube-controller-manager" "kube-scheduler")
  local daemon
  local daemon_status
  printf "%-24s %-10s \n" "PROCESS" "STATUS"
  for daemon in "${required_daemon[@]}"; do
    local rc=0
    kube-ssh "${MASTER}" "sudo systemctl is-active ${daemon}" >/dev/null 2>&1 || rc="$?"
    if [[ "${rc}" -ne "0" ]]; then
      daemon_status="inactive"
    else
      daemon_status="active"
    fi
    printf "%-24s %s\n" ${daemon} ${daemon_status}
  done
  printf "\n"
}

function troubleshoot-node() {
  # Troubleshooting on node if all required daemons are active.
  echo "[INFO] Troubleshooting on node ${1}"
  local -a required_daemon=("kube-proxy" "kubelet" "docker" "flannel")
  local daemon
  local daemon_status
  printf "%-24s %-10s \n" "PROCESS" "STATUS"
  for daemon in "${required_daemon[@]}"; do
    local rc=0
    kube-ssh "${1}" "sudo systemctl is-active ${daemon}" >/dev/null 2>&1 || rc="$?"
    if [[ "${rc}" -ne "0" ]]; then
      daemon_status="inactive"
    else
      daemon_status="active"
    fi
    printf "%-24s %s\n" ${daemon} ${daemon_status}
  done
  printf "\n"
}

# Instantiate a kubernetes cluster
function kube-up {
  # downloading tarball release
  $(${KUBE_ROOT}/cluster/rackhd/build.sh download)

  detect-master
  provision-master
  for node in ${NODES}; do
    provision-node ${node}
  done

  # set CONTEXT and KUBE_SERVER values for create-kubeconfig()
  export CONTEXT="centos"
  export KUBE_SERVER="http://${KUBE_MASTER_IP}:8080"
  source "${KUBE_ROOT}/cluster/common.sh"

  # set kubernetes user and password
  load-or-gen-kube-basicauth
  create-kubeconfig
}

# Delete a kubernetes cluster
function kube-down {
	echo "TODO: kube-down" 1>&2
}

# Update a kubernetes cluster
function kube-push {
	echo "TODO: kube-push" 1>&2
}

# Prepare update a kubernetes component
function prepare-push {
	echo "TODO: prepare-push" 1>&2
}

# Update a kubernetes master
function push-master {
	echo "TODO: push-master" 1>&2
}

# Update a kubernetes node
function push-node {
	echo "TODO: push-node" 1>&2
}

# Execute prior to running tests to build a release if required for env
function test-build-release {
	echo "TODO: test-build-release" 1>&2
}

# Execute prior to running tests to initialize required structure
function test-setup {
	echo "TODO: test-setup" 1>&2
}

# Execute after running tests to perform any required clean-up
function test-teardown {
	echo "TODO: test-teardown" 1>&2
}

# Create dirs that'll be used during setup on target machine.
#
# Assumed vars:
#   KUBE_TEMP
function ensure-setup-dir() {
  kube-ssh "${1}" "mkdir -p ${KUBE_TEMP}; \
                   sudo mkdir -p /opt/kubernetes/bin; \
                   sudo mkdir -p /opt/kubernetes/cfg"
}

# Run command over ssh
function kube-ssh() {
  local host="$1"
  shift
  ssh ${SSH_OPTS} -t "${host}" "$@" >/dev/null 2>&1
}

# Copy file recursively over ssh
function kube-scp() {
  local host="$1"
  local src=($2)
  local dst="$3"
  scp -r ${SSH_OPTS} ${src[*]} "${host}:${dst}"
}
# Provision master
#
# Assumed vars:
#   MASTER
#   KUBE_TEMP
#   ETCD_SERVERS
#   SERVICE_CLUSTER_IP_RANGE
function provision-master() {
  echo "[INFO] Provision master on ${MASTER}"
  local master_ip=${MASTER#*@}
  ensure-setup-dir ${MASTER}

  # scp -r ${SSH_OPTS} master config-default.sh copy-files.sh util.sh "${MASTER}:${KUBE_TEMP}"
  kube-scp ${MASTER} "${ROOT}/../saltbase/salt/generate-cert/make-ca-cert.sh ${ROOT}/binaries/master ${ROOT}/master ${ROOT}/config-default.sh ${ROOT}/util.sh" "${KUBE_TEMP}"
  kube-ssh "${MASTER}" " \
    sudo cp -r ${KUBE_TEMP}/master/bin /opt/kubernetes; \
    sudo chmod -R +x /opt/kubernetes/bin; \
    sudo bash ${KUBE_TEMP}/make-ca-cert.sh ${master_ip} IP:${master_ip},IP:${SERVICE_CLUSTER_IP_RANGE%.*}.1,DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster.local; \
    sudo bash ${KUBE_TEMP}/master/scripts/etcd.sh; \
    sudo bash ${KUBE_TEMP}/master/scripts/apiserver.sh ${master_ip} ${ETCD_SERVERS} ${SERVICE_CLUSTER_IP_RANGE} ${ADMISSION_CONTROL}; \
    sudo bash ${KUBE_TEMP}/master/scripts/controller-manager.sh ${master_ip}; \
    sudo bash ${KUBE_TEMP}/master/scripts/scheduler.sh ${master_ip}"
}


# Provision node
#
# Assumed vars:
#   $1 (node)
#   MASTER
#   KUBE_TEMP
#   ETCD_SERVERS
#   FLANNEL_NET
#   DOCKER_OPTS
function provision-node() {
  echo "[INFO] Provision node on $1"
  local master_ip=${MASTER#*@}
  local node=$1
  local node_ip=${node#*@}
  ensure-setup-dir ${node}

  kube-scp ${node} "${ROOT}/binaries/node ${ROOT}/node ${ROOT}/config-default.sh ${ROOT}/util.sh" ${KUBE_TEMP}
  kube-ssh "${node}" "\
    sudo curl -fsSL https://get.docker.com/ | sh"
  kube-ssh "${node}" " \
    sudo cp -r ${KUBE_TEMP}/node/bin /opt/kubernetes; \
    sudo cp /bin/docker /opt/kubernetes/bin; \
    sudo chmod -R +x /opt/kubernetes/bin; \
    sudo bash ${KUBE_TEMP}/node/scripts/flannel.sh ${ETCD_SERVERS} ${FLANNEL_NET}; \
    sudo bash ${KUBE_TEMP}/node/scripts/docker.sh \"${DOCKER_OPTS}\"; \
    sudo bash ${KUBE_TEMP}/node/scripts/kubelet.sh ${master_ip} ${node_ip}; \
    sudo bash ${KUBE_TEMP}/node/scripts/proxy.sh ${master_ip}"
}
