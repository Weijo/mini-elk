#!/bin/bash

# load .env
if [ -f .env ]; then
	export $(echo $(cat .env | sed 's/#.*//g'| xargs) | envsubst)
fi

KIBANA_HOST="127.0.0.1"

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
	install_integration $f
done