set:
	sudo docker compose up setup --force-recreate

certs:
	sudo docker compose up tls
	sed -i "s?PLEASEDONTREPLACEMEIHAVEABANDONMENTISSUES?`openssl x509 -fingerprint -sha256 -noout -in tls/certs/ca/ca.crt | cut -d '=' -f2 | tr -d ':' | tr '[:upper:]' '[:lower:]'`?" ./kibana/config/kibana.yml

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

reset: prune set run

fileshare:
	sudo python3 -m http.server 8000 --directory ./tls/certs/ca/