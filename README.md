# Localised ELK setup

TLS certificates have been uploaded but if you want to regenerate them run
```
rm -rf tls/certs
./tls.sh
```
This will output the SHA fingerprint, edit `kibana/config/kibana.yml` and find `ca_trusted_fingerprint` and paste the SHA fingerprint there

Edit `.env` file to change the passwords then run
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