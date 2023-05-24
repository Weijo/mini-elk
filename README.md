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

# Localised ELK setup

TLS certificates have been uploaded but if you want to regenerate them run
```
rm -rf tls/certs
./tls.sh
```
This will output the SHA fingerprint, edit `kibana/config/kibana.yml` and find `ca_trusted_fingerprint` and paste the SHA fingerprint there

First time running or after a `docker volume prune` or if you edited `.env` file to change the passwords run this
```
./setup.sh
```

Run the server as such
```
./run.sh
```

# Fleet setup
Fleet should automatically set up by itself. You will need to edit the integration settings

Left side panel go down to Fleet > click on settings > Add fleet server > put the `https://<YOUR VM IP>:8220` and continue

Click on `Add output` > choose a name > type: elasticsearch (for now) > Host: `https://<YOUR VM IP>:9200`> CA trusted (found in kibana.yml) > save

Note that every agent policy you create needs to specify the fleet server and output setting for it to work.

# Agent policies
You can either add them manually through the UI or hardcode into `kibana.yml`, I found the integration names [here](https://epr.elastic.co/search)