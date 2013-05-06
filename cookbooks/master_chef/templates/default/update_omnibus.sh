#!/bin/bash

if [ "$MASTER_CHEF_CONFIG" = "" ]; then
  MASTER_CHEF_CONFIG="/opt/master-chef/etc/local.json"
fi

STATUS_FILE="/opt/master-chef/var/last/result"
LOG_FILE="/opt/master-chef/var/last/log"
REPOS_STATUS_FILE="/opt/master-chef/var/last/repos.json"
LOCAL_STORAGE_FILE="/opt/master-chef/var/local_storage.yml"
FILE_OWNER="<%= @user %>"

log() {
  echo $1 | tee $STATUS_FILE
  chown $FILE_OWNER $STATUS_FILE
}

log "Starting chef using omnibus at `date`"

(
  LOCAL_STORAGE_FILE=$LOCAL_STORAGE_FILE REPOS_STATUS_FILE=$REPOS_STATUS_FILE MASTER_CHEF_CONFIG=$MASTER_CHEF_CONFIG sudo -E /opt/chef/bin/chef-solo -c /opt/master-chef/etc/solo.rb
  if [ "$?" = 0 ]; then
    log "Chef run OK at `date`"
  else
    log "Chef run FAILED at `date`"
  fi
) | tee $LOG_FILE

chown $FILE_OWNER $LOG_FILE
cat $STATUS_FILE | grep OK > /dev/null
