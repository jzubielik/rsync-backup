#!/bin/bash

set -e

CONFIG=${HOME}/.config/rsync-backup/config

function help() {
cat <<EOF
Error: no configuration specified at ${CONFIG}.

Please provide the following variables:

REMOTE_USER=username
REMOTE_HOST=remote.host.address
REMOTE_PATH=/remote/path
LOCAL_PATH=/local/path

EOF
}

test -f ${CONFIG} || (help && exit 1)

IS_RUNNING=$(ps -ef | grep $(basename $0) | grep -vc grep)

if [ ${IS_RUNNING} -gt 2 ]; then
  echo "WARNING! Another instance is already running. Exiting."
  exit
fi

LOG_DIR=${HOME}/.local/log/rsync-backup

LOG_FILE=$(date +%Y%m%d-%H%M%S).log

test -d ${LOG_DIR} || mkdir -p ${LOG_DIR}

LOCK_TIMEOUT=600

RSYNC_OPTS=(
  -aPDAXUH
  --fake-super
  --progress
  --verbose
  --update
  --delete
  --one-file-system
)

for i in ${@}; do
  echo $i
  case ${i} in
    -i)
      exec > >(tee -i ${LOG_DIR}/${LOG_FILE})
      ;;
    init)
      exec > >(tee -i ${LOG_DIR}/${LOG_FILE})
      RSYNC_OPTS=(${RSYNC_OPTS[@]/--delete})
      ;;
    *)
      exec > ${LOG_DIR}/${LOG_FILE}
      exec 2>&1
      ;;
  esac
done

source ${CONFIG}

RSYNC_CMD="rsync ${RSYNC_OPTS[*]}"

REMOTE_LOCK=/tmp/rsync-backup-${USER}-${HOSTNAME}.lock

function is_locked() {
  ssh ${REMOTE_USER}@${REMOTE_HOST} test -f ${REMOTE_LOCK} && echo true || echo false
}

function lock() {
  ssh ${REMOTE_USER}@${REMOTE_HOST} touch ${REMOTE_LOCK}
}

function unlock() {
  ssh ${REMOTE_USER}@${REMOTE_HOST} rm -f ${REMOTE_LOCK}
}

function is_timeouted() {
  CUR_TS=$(date +%s)
  LOCK_TS=$(ssh ${REMOTE_USER}@${REMOTE_HOST} stat -c %Y ${REMOTE_LOCK})
  if [ $[$CUR_TS-$LOCK_TS] -gt ${LOCK_TIMEOUT} ]; then
    echo true
  else
    echo false
  fi
}

function backup() {
  touch ${LOCAL_PATH}/${1}/.sync
  source ${LOCAL_PATH}/${1}/.sync

  RSYNC_EXCLUDES=()
  for i in ${EXCLUDES[*]}; do
    RSYNC_EXCLUDES+=("--exclude '${i}'")
  done

  RSYNC_INCLUDES=()
  for i in ${INCLUDES[*]}; do
    RSYNC_INCLUDES+=("--include '${i}'")
  done

  ${RSYNC_CMD} ${RSYNC_EXCLUDES[*]} ${RSYNC_INCLUDES[*]} ${LOCAL_PATH}/${1}/ ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/${1}
}

function restore() {
  source ${LOCAL_PATH}/${1}/.sync

  RSYNC_EXCLUDES=()
  for i in ${EXCLUDES[*]}; do
    RSYNC_EXCLUDES+=("--exclude '${i}'")
  done

  RSYNC_INCLUDES=()
  for i in ${INCLUDES[*]}; do
    RSYNC_INCLUDES+=("--include '${i}'")
  done

  ${RSYNC_CMD} ${RSYNC_EXCLUDES[*]} ${RSYNC_INCLUDES[*]} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/${1}/ ${LOCAL_PATH}/${1}/
}

function do_sync() {
  ssh ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p ${REMOTE_PATH}/${1}"

  REMOTE_TS=$(ssh ${REMOTE_USER}@${REMOTE_HOST} "test -f ${REMOTE_PATH}/${1}/.sync && stat -c %Y ${REMOTE_PATH}/${1}/.sync || echo 0")

  LOCAL_TS=$(test -f ${LOCAL_PATH}/${1}/.sync && stat -c %Y ${LOCAL_PATH}/${1}/.sync || echo 0)

  REMOTE_IS_EMPTY=$((ssh ${REMOTE_USER}@${REMOTE_HOST} ls -A ${REMOTE_PATH}/${1} | grep -E '.+' >/dev/null && echo false) || echo true)

  LOCAL_IS_EMPTY=$((ls -A ${LOCAL_PATH}/${1} | grep -E '.+' >/dev/null && echo false) || echo true)

  if [ ${REMOTE_IS_EMPTY} == true ]; then
    echo "Sending ${1}..."
    backup ${1}
    restore ${1}
  else
    if [[ $REMOTE_TS -le $LOCAL_TS && ${LOCAL_IS_EMPTY} == false ]]; then
      echo "Sending ${1}..."
      backup ${1}
      restore ${1}
    else
      echo "Receiving ${1}..."
      restore ${1}
      backup ${1}
    fi
  fi
}

SSH_AUTH_SOCK="/run/user/${UID}/keyring/.ssh"

if [ ! -S ${SSH_AUTH_SOCK} ]; then
  SSH_AUTH_SOCK="$(find /tmp/ -type s -path '/tmp/ssh-*/agent.*' -user ${USER} 2>/dev/null)"
fi

export SSH_AUTH_SOCK

until ! $(is_locked); do
  if [ $(is_timeouted) == true ]; then
    echo "Removing stalled lock."
    break
  fi

  echo "Waiting for the lock release..."
  sleep 10
done

FIND_CMD='a=$(dirname $0);a=${a/'
FIND_CMD+=$(echo $LOCAL_PATH | sed -e 's@/@\\/@g')
FIND_CMD+='\//}; echo $a'

lock

for i in $(find ${LOCAL_PATH} -name .sync -exec sh -c "${FIND_CMD}" {} \;); do
  do_sync ${i}
done

unlock
