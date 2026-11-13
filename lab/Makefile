VOLUMES := minigres-pg-primary minigres-pg-replica1 minigres-pg-replica2

.PHONY: lab-volumes lab-up lab-down lab-reset lab-check

lab-volumes:
	@for v in $(VOLUMES); do docker volume inspect $$v >/dev/null 2>&1 || docker volume create $$v; done

lab-up: lab-volumes
	docker compose up -d --wait

# Stops containers, keeps data.
lab-down:
	docker compose down

# Destroys ALL lab data. External volumes survive `down -v`, so remove them by name.
lab-reset:
	docker compose down
	docker volume rm $(VOLUMES) || true

lab-check:
	bash ./check.sh
