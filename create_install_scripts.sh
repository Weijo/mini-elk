#!/bin/bash

# load .env
if [ -f .env ]; then
	export $(echo $(cat .env | sed 's/#.*//g'| xargs) | envsubst)
fi

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

KIBANA_HOST="192.168.147.144"

# Create the scripts directory in fileshare
mkdir -p "./fileshare/scripts"

# Make the API request and capture the response
response=$(curl -X GET \
-s \
--url "https://$KIBANA_HOST:5601/api/fleet/enrollment-api-keys" \
--header "kbn-xsrf: true" \
-k \
-u elastic:$ELASTIC_PASSWORD
)

# Parse the response to extract the policy IDs and enrollment tokens
policies=$(echo "$response" | jq -r '.list[] | [.policy_id, .api_key] | @tsv')

# Loop through the policies and print the policy ID and enrollment token
while IFS=$'\t' read -r policy_id enrollment_token; do
    filename="./fileshare/scripts/${policy_id}_file.sh"
    
    # Create the file for each policy ID
    log "Creating script for policy: $policy_id"
    echo "#!/bin/bash" > "$filename"
    echo "" >> "$filename"
    echo "curl -L -O http://fleet-server:8000/elastic-agent.tar.gz" >> "$filename"
    echo "tar xzvf elastic-agent.tar.gz" >> "$filename"
    echo "cd elastic-agent-8.7.1-linux-x86_64" >> "$filename"
    echo "wget http://fleet-server:8000/ca.crt" >> "$filename"
    echo "caPath=\$(pwd)" >> "$filename"
    echo "sudo ./elastic-agent install --url=https://fleet-server:8220 --enrollment-token=$enrollment_token --certificate-authorities=\$caPath/ca.crt -f" >> "$filename"
    
    # Make the file executable
    chmod +x "$filename"
    
    sublog "Created file: $filename"
done <<< "$policies"