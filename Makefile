.PHONY: setup policies savedObjects tranforms fileshare

setup:
	sudo docker compose up setup --force-recreate

certs:
	sudo docker compose up tls
	sed -i "s?PLEASEDONTREPLACEMEIHAVEABANDONMENTISSUES?`openssl x509 -fingerprint -sha256 -noout -in tls/certs/ca/ca.crt | cut -d '=' -f2 | tr -d ':' | tr '[:upper:]' '[:lower:]'`?" ./kibana/config/kibana.yml
	sed -i "s?PLEASEREPLACEMESAVEOBJECT?`openssl rand -base64 40 | tr -d "=+/" | cut -c1-32`?" ./kibana/config/kibana.yml
	sed -i "s?PLEASEREPLACEMEREPORTING?`openssl rand -base64 40 | tr -d "=+/" | cut -c1-32`?" ./kibana/config/kibana.yml
	sed -i "s?PLEASEREPLACEMESECURITY?`openssl rand -base64 40 | tr -d "=+/" | cut -c1-32`?" ./kibana/config/kibana.yml
test:
	sudo docker compose -f docker-compose.yml up

run:
	sudo docker compose -f docker-compose.yml up -d

down:
	sudo docker compose down

build:
	sudo docker compose build

ps:
	sudo docker compose ps

prune:
	sudo docker container prune -f
	sudo docker volume prune -a -f 
	sudo docker network prune -f

policies:
	bash ./setup_policies.sh

savedObjects:
	bash ./setup_savedobjects.sh

tranforms:
	bash ./setup_transforms.sh

reset: prune setup run

up: certs setup run policies tranforms savedObjects

fileshare:
	mkdir -p fileshare
	test -f ./fileshare/ca.crt || cp ./tls/certs/ca/ca.crt ./fileshare/ca.crt
	test -f ./fileshare/apm-server.crt || cp ./tls/certs/apm-server/apm-server.crt ./fileshare/apm-server.crt
	test -f ./fileshare/elastic-agent.tar.gz || curl -L "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-8.7.1-linux-x86_64.tar.gz" -o ./fileshare/elastic-agent.tar.gz
	sudo python3 -m http.server 8000 --directory=./fileshare