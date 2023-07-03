#!/bin/bash

# load .env
if [ -f .env ]; then
	export $(echo $(cat .env | sed 's/#.*//g'| xargs) | envsubst)
fi

KIBANA_HOST="127.0.0.1"

# Log a message.
function log {
	echo "[+] $1"
}

# Log a message at a sub-level.
function sublog {
	echo "   ⠿ $1"
}

# Log an error.
function err {
	echo "[x] $1" >&2
}

# Log an error at a sub-level.
function suberr {
	echo "   ⠍ $1" >&2
}

function install_integration {
	local filename=$1

	local output
	
	output=$(curl --request POST \
	-s \
	--url "https://$KIBANA_HOST:5601/api/fleet/package_policies" \
	--header 'Content-Type: application/json' \
	--header 'kbn-xsrf: xxx' \
	-k \
	-u elastic:$ELASTIC_PASSWORD \
	--data @$filename
	)

	echo "$output"
}

FILES="./policies/*.json"
for f in $FILES
do
	log "Adding $f"
	install_integration $f
done