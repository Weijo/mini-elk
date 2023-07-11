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
    linux_scriptname="./fileshare/scripts/${policy_id}_linux.sh"
    windows_scriptname="./fileshare/scripts/${policy_id}_windows.sh"

    # Create the file for each policy ID
    log "Creating scripts for policy: $policy_id"

    # Linux script
    echo "#!/bin/bash" > "$linux_scriptname"
    echo "" >> "$linux_scriptname"
    echo "curl -L -O http://fleet-server:8000/elastic-agent.tar.gz" >> "$linux_scriptname"
    echo "tar xzvf elastic-agent.tar.gz" >> "$linux_scriptname"
    echo "cd elastic-agent-8.7.1-linux-x86_64" >> "$linux_scriptname"
    echo "wget http://fleet-server:8000/ca.crt" >> "$linux_scriptname"
    echo "caPath=\$(pwd)" >> "$linux_scriptname"
    echo "sudo ./elastic-agent install --url=https://fleet-server:8220 --enrollment-token=$enrollment_token --certificate-authorities=\$caPath/ca.crt -f" >> "$linux_scriptname"
    sublog "Created Linux script: $linux_scriptname"
    
    # Windows script
    echo echo "\$url = 'http://fleet-server:8000/elastic-agent-windows.zip'" > "$windows_scriptname"
    echo "$ProgressPreference = 'SilentlyContinue'" >> "$windows_scriptname"
    echo "Invoke-WebRequest -Uri http://fleet-server:8000/elastic-agent-windows.zip -OutFile elastic-agent-windows.zip" >> "$windows_scriptname"
    echo "Expand-Archive .\elastic-agent-windows.zip -DestinationPath ." >> "$windows_scriptname"
    echo "cd elastic-agent-8.7.1-windows-x86_64" >> "$windows_scriptname"
    echo "Invoke-WebRequest -Uri 'http://fleet-server:8000/ca.crt' -OutFile .\ca.crt" >> "$windows_scriptname"
    echo "\$caPath = (Get-Location).Path" >> "$windows_scriptname"
    echo ".\elastic-agent.exe install --url=https://fleet-server:8220 --enrollment-token=$enrollment_token --certificate-authorities=\$caPath\ca.crt -f" >> "$windows_scriptname"
    sublog "Created Windows script: $windows_scriptname"

    # Make the file executable
    chmod +x "$linux_scriptname"
    chmod +x "$windows_scriptname"
    
done <<< "$policies"