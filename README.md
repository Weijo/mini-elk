# Requirements
Mini-elk was tested on Ubuntu 23.04 (Live and desktop)

You need make, docker and docker-compose. Docker has to have the docker-init plugin
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
sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo apt-get install make -y
```

# Localised ELK setup
I placed the various docker commands into a [Makefile](./Makefile)

you can set everything up in one command
```
make up
```

## Commands
`certs` will generate the TLS certs and replace the SHA256 sum to the `kibana.yml`. It will also generate the encryption keys for `kibana.yml`
```
make certs
```

`setup` will run the `setup` docker container which will set up the passwords, and add ingest pipelines and index templates.
use this after a `docker volume prune` or if you edited `.env` file to change the passwords run this
```
make setup
```

`run` will run the server as daemon
```
make run
```

`test` will run the server without daemon (for testing)
```
make test
```

`ps` will run docker compose ps
```
make ps
```

`down` will run docker compose down
```
make down
```

`build` will run docker compose build
```
make build
```

`prune` will forcefully remove existing volumes, networks and containers
```
make prune
```

`policies`, `savedObjects`, `tranforms` will run respective setup scripts: `setup_policies.sh`, `setup_savedobjects.sh`, `setup_transforms.sh`
```
make policies
make savedObjects
make tranforms
```

`scripts` will curl the fleet api for the enrollment tokens and create installation scripts in the fileshare server
```
make scripts
```

`reset` runs `prune`,`setup` and `run`
```
make reset
```

`fileshare` sets up the fileshare to distribute the certificates and elastic agent
```
make fileshare
```

# Fleet setup
Fleet should automatically set up by itself. 

If you want to add a different output/fleet server:
Left side panel go down to Fleet > click on settings > Add fleet server > put the `https://<YOUR VM IP>:8220` and continue

Click on `Add output` > choose a name > type: elasticsearch (for now) > Host: `https://<YOUR VM IP>:9200`> CA trusted (found in kibana.yml) > save

Note that every agent policy you create needs to specify the fleet server and output setting for it to work.

# Fleet dying
When you turn off the VM and turn it on after a while, you may notice the fleet-server or other agents being dead.

Checking the logs will show something like this:
```
"message":"Error fetching data for metricset beat.state: error making http request: Get "http://unix/state/": dial unix /usr/share/elastic-agent/state/data/tmp/fleet-server-default.sock: connect: no such file or directory"
```

When this happens, try to go into the affected elastic agent server and restart elastic-agent. E.g
```
sudo docker exec -it mini-elk-fleet-server-1 /bin/bash
elastic-agent restart
```

# Agent policies
You can either add them manually through the UI or hardcode into `kibana.yml`, I found the integration names [here](https://epr.elastic.co/search)

Writing the policies is really hard as there are barely any examples but if you search for `manifest.yml` in `elastic/integration` repo there are some examples you can follow
https://github.com/search?q=repo%3Aelastic%2Fintegrations+manifest.yml&type=code

That being said, its better to use the preview API and write your own script to add the integration like what I did in `setup_policies.sh`

# Enrolling agents
add the elastic vm ip to `/etc/hosts`

```
192.168.147.138 fleet-server elasticsearch
```

If the elk server is fully up and running, you can run one of the following command
```
curl http://fleet-server:8000/scripts/ctfd-policy_linux.sh | bash
curl http://fleet-server:8000/scripts/webserver-policy_linux.sh | bash
curl http://fleet-server:8000/scripts/limesurvey-policy_linux.sh | bash
curl http://fleet-server:8000/scripts/kali-policy_linux.sh | bash
```

For windows, open powershell as administrator
```
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Invoke-WebRequest -Uri 'http://fleet-server:8000/scripts/corporate-endpoint-policy_windows.ps1' -OutFile 'script.sh'; .\script.sh
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Restricted
rm .\script.sh
```

You will need to transfer the `ca.crt` file to the agent vm. The way I did it is through python http server, run this on elastic vm. This will create 
```
make fileshare
```

then run the command below, replace the `enrollment-token` and the `certificate-authorities` argument with the **ABSOLUTE** path to your ca.crt
```
curl -L -O http://fleet-server:8000/elastic-agent.tar.gz
tar xzvf elastic-agent.tar.gz
cd elastic-agent-8.7.1-linux-x86_64
wget http://fleet-server:8000/ca.crt
caPath=$(pwd)
sudo ./elastic-agent install --url=https://fleet-server:8220 --enrollment-token=<CHANGEME> --certificate-authorities=$caPath/ca.crt
```

# Custom logging
Refer to [Custom-Logging.md](./Custom-Logging.md)

# APM agents
So far I've only done this on the CTFd server which is a flask application.

Edit `requirements.txt` and add in the following:
```
elastic-apm[flask]
```

Now that we have elasticapm library added, edit python file that creates the Flask() app. 
In this case its the `CTFd/__init__.py` file.

add in the following code
```python
from elasticapm.contrib.flask import ElasticAPM

def create_app(config="CTFd.config.Config"):
    app = CTFdFlask(__name__)

    app.config['ELASTIC_APM'] = {
          'SERVICE_NAME': 'CTFd',
          'SECRET_TOKEN': '',
          'SERVER_URL': 'https://apm-server:8200',
          'SERVER_CERT': '/opt/CTFd/apm-server.crt'
    }

    apm = ElasticAPM(app)
```

The next part is editing the `docker-compose.yml` file to set the dns record for `apm-server`.
This is set under the `extra_hosts` option
```yaml
services:
  ctfd:
    build: .
    user: root
    restart: always
    environment:
      - UPLOAD_FOLDER=/var/uploads
      - DATABASE_URL=mysql+pymysql://ctfd:ctfd@db/ctfd
      - REDIS_URL=redis://cache:6379
      - WORKERS=4
      - LOG_FOLDER=/var/log/CTFd
      - ACCESS_LOG=/var/log/CTFd/access.log
      - ERROR_LOG=/var/log/CTFd/error.log
      - REVERSE_PROXY=true
    volumes:
      - .data/CTFd/logs:/var/log/CTFd
      - .data/CTFd/uploads:/var/uploads
      - .:/opt/CTFd:ro
    depends_on:
      - db
    extra_hosts:
      - "apm-server:192.168.147.144"
    networks:
        default:
        internal:
```

Now we need to download the apm-server certificate. On the elk stack run
```
make fileshare
```

This should host the certificate files. Now we can do to CTFd server and download the certificate
```
wget http://apm-server:8000/apm-server.crt
```

And finally, build the docker container and we should be alright
```
sudo docker compose build
sudo docker compose up -d
```


# Credits
- Docker-elk - https://github.com/deviantony/docker-elk
- pfelk - https://github.com/pfelk/pfelk
