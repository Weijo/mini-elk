#!/bin/bash

# load .env
if [ -f .env ]; then
	export $(echo $(cat .env | sed 's/#.*//g'| xargs) | envsubst)
fi

ELASTIC_HOST="192.168.147.144"

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

function install_transforms {
	local filename=$1
    local transform_name=$(basename "$filename" .json)
	local output
	
	output=$(curl --request PUT \
	-s \
	--write-out "%{http_code}" \
	--url "https://$ELASTIC_HOST:9200/_transform/$transform_name" \
	--header 'Content-Type: application/json' \
	-k \
	-u elastic:$ELASTIC_PASSWORD \
	--data @$filename
	)

	if [[ "${output: -3}" -eq 400 ]]; then 
		suberr "Transform already exists"
	elif [[ "${output: -3}" -eq 200 ]]; then 
		sublog "Transform added"
	fi

}

FILES="./transforms/*.json"
for f in $FILES
do
	log "Adding $f"
	install_transforms $f
done