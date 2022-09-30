# *** DJANGO ***

.PHONY: run-django
run-django:  ## Run django application with debugger
	$(ACTIVATE) && python manage.py runserver 0.0.0.0:8000

.PHONY: run-django-collectstatic
run-django-collectstatic:  ## Run django collectstatic
	$(ACTIVATE) && python manage.py collectstatic --link --noinput

.PHONY: run-django-migrate
run-django-migrate:  ## Run django migrate
	$(ACTIVATE) && python manage.py migrate

.PHONY: run-django-supervisord
run-django-supervisord:  ## Run flask application with supervisord
	$(ACTIVATE) && supervisord -c "$(MISC)/supervisord.docker.conf"
