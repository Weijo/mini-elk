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
# Pipelines declarations

declare -A pipeline_files
pipeline_files=(
	[kali.commandhistory]='kali_commandhistory.json'
	[ctfd.submissions]='ctfd_submissions.json'
	[ctfd.registrations]='ctfd_registrations.json'
	[ctfd.logins]='ctfd_logins.json'
)

# --------------------------------------------------------
# pfELK templates declarations

declare -A pfelk_templates
pfelk_templates=(
	[pfelk-mappings-ecs]='_component_template'
	[pfelk-ilm]='_ilm/policy'
	[pfelk]='_index_template'
	[pfelk-dhcp]='_index_template'
	[pfelk-suricata]='_index_template'
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
log 'Adding ingest pipelines'

for pipeline in "${!pipeline_files[@]}"; do
	log "Pipeline '$pipeline'"

	declare body_file2
	body_file2="${BASH_SOURCE[0]%/*}/pipelines/${pipeline_files[$pipeline]:-}"
	if [[ ! -f "${body_file2:-}" ]]; then
		sublog "No pipeline body found at '${body_file2}', skipping"
		continue
	fi

	sublog 'Creating'
	add_pipeline "$pipeline" "$(<"${body_file2}")"
done

# Add pfelk templates
log 'Adding pfelk templates'

for template in "${!pfelk_templates[@]}"; do
	log "Template '$template'"

	declare filename
	filename="${BASH_SOURCE[0]%/*}/pfelk_templates/${template}.json"
	if [[ ! -f "${filename:-}" ]]; then
		sublog "No pipeline body found at '${filename}', skipping"
		continue
	fi

	sublog 'Creating'
	install_pfelk "$template" "${filename}" "${pfelk_templates[$template]:-}"
done