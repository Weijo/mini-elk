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

function install_savedobjects {
	local filename=$1
	local output
    # curl -X POST https://192.168.147.144:5601/api/saved_objects/_import -H "kbn-xsrf: true" --form file=@./savedObjects/suricata.ndjson -u elastic:changeme -k
	output=$(curl --request POST \
	-s \
	--write-out "%{http_code}" \
	--url "https://$KIBANA_HOST:5601/api/saved_objects/_import" \
    --header "kbn-xsrf: true" \
    --form file=@$filename \
	-k \
	-u elastic:$ELASTIC_PASSWORD
	)

	if [[ "${output: -3}" -eq 400 ]]; then 
		suberr "Saved Object already exists"
	elif [[ "${output: -3}" -eq 200 ]]; then 
		sublog "Saved Object added"
	fi

}

FILES="./savedObjects/*.ndjson"
for f in $FILES
do
	log "Adding $f"
	install_savedobjects $f
done