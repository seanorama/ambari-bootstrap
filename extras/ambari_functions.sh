#!/usr/bin/env bash
## really bad hacked scripts that I've written dozens of times and
##   finally going to start consolidating ...

## todo: include my code that's in bdutil:
##   https://github.com/GoogleCloudPlatform/bdutil/blob/master/platforms/hdp/ambari_functions.sh

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

test -f ${__dir}/.ambari.conf && source ${__dir}/.ambari.conf
test -f ~/.ambari.conf && source ~/.ambari.conf

ambari_user=${ambari_user:-admin}
ambari_pass=${ambari_pass:-admin}
ambari_protocol=${ambari_protocol:-http}
ambari_host=${ambari_host:-localhost}
ambari_port=${ambari_port:-8080}
ambari_api="${ambari_protocol}://${ambari_host}:${ambari_port}/api/v1"
ambari_curl_cmd="curl -ksSu ${ambari_user}:${ambari_pass} -H x-requested-by:sean"
export ambari_curl="${ambari_curl_cmd} ${ambari_api}"

## auto-detect cluster

ambari_get_cluster() {
  ambari_cluster=$(${ambari_curl}/clusters \
      | python -c 'import sys,json; \
            print json.load(sys.stdin)["items"][0]["Clusters"]["cluster_name"]')
}

ambari_configs() {
  ambari_get_cluster
  ambari_configs_sh="/var/lib/ambari-server/resources/scripts/configs.sh \
    -u ${ambari_user} -p ${ambari_pass} \
    -port ${ambari_port} $(if [ ${ambari_protocol} == 'https' ]; then echo '-s '; fi)"
  ambari_config_set="${ambari_configs_sh} set ${ambari_host} ${ambari_cluster}"
  ambari_config_get="${ambari_configs_sh} get ${ambari_host} ${ambari_cluster}"

  #defaultfs=$(${config_get} core-site | awk -F'"' '$2 == "fs.defaultFS" {print $4}' | head -1)
}

ambari_change_pass() {
  # expects: ambari_change_pass username oldpass newpass
read -r -d '' body <<EOF
{ "Users": { "user_name": "$1", "old_password": "$2", "password": "$3" }}
EOF

  echo ${body}
  echo "${body}" | ${ambari_curl}/users/$1 \
    -v -X PUT -d @-
}

AMBARI_TIMEOUT=${AMBARI_TIMEOUT:-3600}
POLLING_INTERVAL=${POLLING_INTERVAL:-10}

function ambari_wait() {
  local condition="$1"
  local goal="$2"
  local failed="FAILED"
  local limit=$(( ${AMBARI_TIMEOUT} / ${POLLING_INTERVAL} + 1 ))

  for (( i=0; i<${limit}; i++ )); do
    local status=$(bash -c "${condition}")
    if [ "${status}" = "${goal}" ]; then
      break
    elif [ "${status}" = "${failed}" ]; then
      echo "Ambari operiation failed with status: ${status}" >&2
      return 1
    fi
    echo "ambari_wait status: ${status}" >&2
    sleep ${POLLING_INTERVAL}
  done

  if [ ${i} -eq ${limit} ]; then
    echo "ambari_wait did not finish within" \
        "'${AMBARI_TIMEOUT}' seconds. Exiting." >&2
    return 1
  fi
}

# Only useful during a fresh install where we expect no failures
# Will not work if any requested TIMEDOUT/ABORTED
function ambari_wait_requests_completed() {
      ambari_get_cluster
      # Poll for completion
      ambari_wait "${ambari_curl}/clusters/${ambari_cluster}/requests \
            | grep -Eo 'http://.*/requests/[^\"]+' \
            | tail -1 \
            | xargs ${ambari_curl_cmd} \
            | grep request_status \
            | uniq \
            | tr -cd '[:upper:]'" \
            'COMPLETED'
}

function ambari_wait_request_complete() {
      ambari_get_cluster
      # Poll for completion
      ambari_wait "${ambari_curl}/clusters/${ambari_cluster}/requests/${1} \
            | grep request_status \
            | uniq \
            | tr -cd '[:upper:]'" \
            'COMPLETED'
}

