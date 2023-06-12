set:
	sudo docker compose up setup

certs:
	sudo docker compose up tls

test:
	sudo docker compose -f docker-compose.yml up

run:
	sudo docker compose -f docker-compose.yml up -d

ps:
	sudo docker compose ps

prune:
	sudo docker container prune
	sudo docker volume prune -a

reset: prune set run