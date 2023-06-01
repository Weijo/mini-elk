# Requirements

You need docker and docker-compose. Docker has to have the docker-init plugin
```
Client: Docker Engine - Community
 Version:           24.0.1
 API version:       1.43
 Go version:        go1.20.4
 Git commit:        6802122
 Built:             Fri May 19 18:06:18 2023
 OS/Arch:           linux/amd64
 Context:           default

Server: Docker Engine - Community
 Engine:
  Version:          24.0.1
  API version:      1.43 (minimum version 1.12)
  Go version:       go1.20.4
  Git commit:       463850e
  Built:            Fri May 19 18:06:18 2023
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          1.6.21
  GitCommit:        3dce8eb055cbb6872793272b4f20ed16117344f8
 runc:
  Version:          1.1.7
  GitCommit:        v1.1.7-0-g860f061
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0
```

Follow the steps [here](https://docs.docker.com/engine/install/ubuntu/)

```
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

# Localised ELK setup

First time setup requires you to generate the TLS certifications
```
./tls.sh
```
This will output the SHA fingerprint, edit `kibana/config/kibana.yml`, find `ca_trusted_fingerprint` and replace the SHA fingerprint there

First time running or after a `docker volume prune` or if you edited `.env` file to change the passwords run this
```
./setup.sh
```

Run the server as such
```
./run.sh
```

Regenerate the xpack encryption keys when used in production as they're shown publically. The keys are needed for Elastic security Alerts to load/work
```bash
sudo docker container run --rm docker.elastic.co/kibana/kibana:8.7.1 bin/kibana-encryption-keys generate
```


# Fleet setup
Fleet should automatically set up by itself. 

If you want to add a different output/fleet server:
Left side panel go down to Fleet > click on settings > Add fleet server > put the `https://<YOUR VM IP>:8220` and continue

Click on `Add output` > choose a name > type: elasticsearch (for now) > Host: `https://<YOUR VM IP>:9200`> CA trusted (found in kibana.yml) > save

Note that every agent policy you create needs to specify the fleet server and output setting for it to work.

# Agent policies
You can either add them manually through the UI or hardcode into `kibana.yml`, I found the integration names [here](https://epr.elastic.co/search)

# Enrolling agents
add the elastic vm ip to `/etc/hosts`

```
192.168.147.138 fleet-server elasticsearch
```
You will need to transfer the `ca.crt` file to the agent vm. The way I did it is through python http server, run this on elastic vm
```
cd ~/mini-elk/tls/certs/ca
python3 -m http.server 8000
```

then run the command, replace the `certificate-authorities` argument with the **ABSOLUTE** path to your ca.crt
```
wget http://fleet-server:8000/ca.crt
curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-8.7.1-linux-x86_64.tar.gz
tar xzvf elastic-agent-8.7.1-linux-x86_64.tar.gz
cd elastic-agent-8.7.1-linux-x86_64
sudo ./elastic-agent install --url=https://fleet-server:8220 --enrollment-token=Q0NxUlRJZ0JQa0xtUzM1Q1g2aVo6dWVRZlFENTJRbHVvb3U0bUc5LV9DZw== --certificate-authorities=/home/kali/elastic-agent-8.7.1-linux-x86_64/ca.crt
```

# Custom logging
Refer to [Custom-Logging.md](./Custom-Logging.md)
