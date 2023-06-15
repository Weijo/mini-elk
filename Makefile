set:
	sudo docker compose up setup

certs:
	sudo docker compose up tls
	sed -i "s?PLEASEDONTREPLACEMEIHAVEABANDONMENTISSUES?`openssl x509 -fingerprint -sha256 -noout -in tls/certs/ca/ca.crt | awk -F"=" {' print $2 '} | sed s/://g`?" ./kibana/config/kibana.yml

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