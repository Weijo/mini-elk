set:
	sudo docker compose up setup

certs:
	sudo docker compose up tls

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