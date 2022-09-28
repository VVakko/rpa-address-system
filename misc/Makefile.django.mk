# *** DJANGO ***

.PHONY: run-django
run-django:  ## Run django application with debugger
	$(ACTIVATE) && python manage.py runserver 0.0.0.0:8000
