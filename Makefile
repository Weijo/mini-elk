set:
	sudo docker compose up setup

certs:
	sudo docker compose up tls
	ca_fingerprint="$(openssl x509 -fingerprint -sha256 -noout -in tls/certs/ca/ca.crt \
		| cut -d '=' -f2 \
		| tr -d ':' \
		| tr '[:upper:]' '[:lower:]'
	)"
	sed -i "s?PLEASEDONTREPLACEMEIHAVEABANDONMENTISSUES?$ca_fingerprint?" ./kibana/config/kibana.yml

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

reset: prune set run