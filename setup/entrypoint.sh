#!/usr/bin/env bash

set -eu
set -o pipefail

source "${BASH_SOURCE[0]%/*}"/lib.sh


# --------------------------------------------------------
# Users declarations

declare -A users_passwords
users_passwords=(
	[logstash_internal]="${LOGSTASH_INTERNAL_PASSWORD:-}"
	[logstash_system]="${LOGSTASH_SYSTEM_PASSWORD:-}"
	[kibana_system]="${KIBANA_SYSTEM_PASSWORD:-}"
	[metricbeat_internal]="${METRICBEAT_INTERNAL_PASSWORD:-}"
	[filebeat_internal]="${FILEBEAT_INTERNAL_PASSWORD:-}"
	[heartbeat_internal]="${HEARTBEAT_INTERNAL_PASSWORD:-}"
	[monitoring_internal]="${MONITORING_INTERNAL_PASSWORD:-}"
	[beats_system]="${BEATS_SYSTEM_PASSWORD=:-}"
)

declare -A users_roles
users_roles=(
	[logstash_internal]='logstash_writer'
	[metricbeat_internal]='metricbeat_writer'
	[filebeat_internal]='filebeat_writer'
	[heartbeat_internal]='heartbeat_writer'
	[monitoring_internal]='remote_monitoring_collector'
)

# --------------------------------------------------------
# Roles declarations

declare -A roles_files
roles_files=(
	[logstash_writer]='logstash_writer.json'
	[metricbeat_writer]='metricbeat_writer.json'
	[filebeat_writer]='filebeat_writer.json'
	[heartbeat_writer]='heartbeat_writer.json'
)

# --------------------------------------------------------


log 'Waiting for availability of Elasticsearch. This can take several minutes.'

declare -i exit_code=0
wait_for_elasticsearch || exit_code=$?

if ((exit_code)); then
	case $exit_code in
		6)
			suberr 'Could not resolve host. Is Elasticsearch running?'
			;;
		7)
			suberr 'Failed to connect to host. Is Elasticsearch healthy?'
			;;
		28)
			suberr 'Timeout connecting to host. Is Elasticsearch healthy?'
			;;
		*)
			suberr "Connection to Elasticsearch failed. Exit code: ${exit_code}"
			;;
	esac

	exit $exit_code
fi

sublog 'Elasticsearch is running'

log 'Waiting for initialization of built-in users'

wait_for_builtin_users || exit_code=$?

if ((exit_code)); then
	suberr 'Timed out waiting for condition'
	exit $exit_code
fi

sublog 'Built-in users were initialized'

for role in "${!roles_files[@]}"; do
	log "Role '$role'"

	declare body_file
	body_file="${BASH_SOURCE[0]%/*}/roles/${roles_files[$role]:-}"
	if [[ ! -f "${body_file:-}" ]]; then
		sublog "No role body found at '${body_file}', skipping"
		continue
	fi

	sublog 'Creating/updating'
	ensure_role "$role" "$(<"${body_file}")"
done

for user in "${!users_passwords[@]}"; do
	log "User '$user'"
	if [[ -z "${users_passwords[$user]:-}" ]]; then
		sublog 'No password defined, skipping'
		continue
	fi

	declare -i user_exists=0
	user_exists="$(check_user_exists "$user")"

	if ((user_exists)); then
		sublog 'User exists, setting password'
		set_user_password "$user" "${users_passwords[$user]}"
	else
		if [[ -z "${users_roles[$user]:-}" ]]; then
			suberr '  No role defined, skipping creation'
			continue
		fi

		sublog 'User does not exist, creating'
		create_user "$user" "${users_passwords[$user]}" "${users_roles[$user]}"
	fi
done

# Add in ingest pipelines
log 'Adding Ingest pipelines'

es_ca_cert="${BASH_SOURCE[0]%/*}"/ca.crt

curl -X PUT "https://elasticsearch:9200/_ingest/pipeline/kali.commandhistory?pretty" -u "elastic:${ELASTIC_PASSWORD}" --cacert "$es_ca_cert" -H 'Content-Type: application/json' -d'
{
  "description": "Parsing for kali logs",
  "processors": [
    {
      "grok": {
        "field": "message",
        "patterns": [
          "%{TIMESTAMP_ISO8601:timestamp} %{DATA:name1} %{DATA:name2}: {\"user\": \"%{DATA:users}\", \"path\": \"%{DATA:path}\", \"pid\": \"%{NUMBER:pid}\",\"original_command\": \"%{DATA:original_command}\", \"status\": \"%{NUMBER:status}\"}"
        ]
      }
    }
  ]
}
'

curl -X PUT "https://elasticsearch:9200/_ingest/pipeline/ctfd-submission?pretty" -u "elastic:${ELASTIC_PASSWORD}" --cacert "$es_ca_cert" -H 'Content-Type: application/json' -d'
{
  "description": "Parsing for ctfd submission logs",
  "processors": [
    {
      "set": {
        "field": "event.ingested",
        "copy_from": "_ingest.timestamp"
      }
    },
    {
      "grok": {
        "field": "message",
        "patterns": [
          "^\\[%{DATESTAMP:datestamp}\\] %{DATA:user} submitted b'%{DATA:flag}' on %{NUMBER:challengeNo} with kpm %{NUMBER:tries} \\[%{DATA:result}\\]"
        ]
      }
    },
    {
      "set": {
        "field": "event.dataset",
        "value": "ctfdsubmission"
      }
    }
  ],
  "on_failure": [
    {
      "set": {
        "field": "error.message",
        "value": "{{ _ingest.on_failure_message }}"
      }
    }
  ]
}
'

curl -X PUT "https://@elasticsearch:9200/_ingest/pipeline/ctfd.registrations?pretty" -u "elastic:${ELASTIC_PASSWORD}" --cacert "$es_ca_cert" -H 'Content-Type: application/json' -d'
{
  "description": "Parsing for ctfd registration logs",
  "processors": [
    {
      "set": {
        "field": "event.ingested",
        "copy_from": "_ingest.timestamp"
      }
    },
    {
      "grok": {
        "field": "message",
        "patterns": [
          "^\\[%{DATESTAMP:datestamp}\\] %{IP:source} - %{DATA:user} registered with %{DATA:email}$"
        ]
      }
    },
    {
      "set": {
        "field": "event.dataset",
        "value": "ctfd.registrations"
      }
    }
  ],
  "on_failure": [
    {
      "set": {
        "field": "error.message",
        "value": "{{ _ingest.on_failure_message }}"
      }
    }
  ]
}
'