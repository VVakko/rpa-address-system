# RPA Address System

We're going to create a simple API to perform various types of search in the address system.

## Project setup

Copy the standard template for a python microservice.

    $ pwd
    <some path>/rpa-address-system
    $ find . -type f
    ./data/.gitkeep
    ./.gitignore
    ./.gitlab-ci.yml
    ./Makefile
    ./misc/docker-compose.yml
    ./misc/Dockerfile
    ./misc/.flake8
    ./misc/.pylintrc
    ./README.md
    ./requirements.dev.txt
    ./tests/.coveragerc
    ./tests/__init__.py
    ./tests/pytest.ini

    # Create a virtual environment to isolate our package dependencies locally
    $ export PIP_INDEX_URL="https://git.acmenet.ru/pypi/root/pypi/+simple/"
    $ export PIP_TRUSTED_HOST="git.acmenet.ru"
    $ make venv-init
    $ source .venv/bin/activate

    # Install linters, pytest and other general packages
    $ make venv-deps-upgrade

    # Save dependencies to 'requirements.txt' file (with versions)
    $ make venv-deps-freeze-and-save

Create a new Django project named `app`, then start a new app called `gar`.

    # Install Django and Django REST framework into the virtual environment
    # Add `django==3.2.4`, `djangorestframework`, `m3-gar`, `m3-rest-gar` and `psycopg2-binary` to the `requirements.dev.txt` and then execute next commands:
    $ make venv-deps-upgrade
    $ make venv-deps-freeze-and-save

    # Set up a new Django project with a single application
    $ django-admin startproject app .  # Don't forget about the trailing '.' character
    $ cd app
    $ django-admin startapp gar
    $ cd ..

The project layout should look like:

    $ find . -name '*.py' -not -path './.venv/*'
    ./manage.py
    ./app/wsgi.py
    ./app/settings.py
    ./app/urls.py
    ./app/asgi.py
    ./app/__init__.py
    ./app/gar/models.py
    ./app/gar/views.py
    ./app/gar/apps.py
    ./app/gar/tests.py
    ./app/gar/admin.py
    ./app/gar/migrations/__init__.py
    ./app/gar/__init__.py
    ./tests/__init__.py

Now sync your database for the first time:

    $ python manage.py migrate
    Operations to perform:
    Apply all migrations: admin, auth, contenttypes, sessions
    Running migrations:
    Applying contenttypes.0001_initial... OK
    Applying auth.0001_initial... OK
    Applying admin.0001_initial... OK
    Applying admin.0002_logentry_remove_auto_add... OK
    Applying admin.0003_logentry_add_action_flag_choices... OK
    Applying contenttypes.0002_remove_content_type_name... OK
    Applying auth.0002_alter_permission_name_max_length... OK
    Applying auth.0003_alter_user_email_max_length... OK
    Applying auth.0004_alter_user_username_opts... OK
    Applying auth.0005_alter_user_last_login_null... OK
    Applying auth.0006_require_contenttypes_0002... OK
    Applying auth.0007_alter_validators_add_error_messages... OK
    Applying auth.0008_alter_user_username_max_length... OK
    Applying auth.0009_alter_user_last_name_max_length... OK
    Applying auth.0010_alter_group_name_max_length... OK
    Applying auth.0011_update_proxy_permissions... OK
    Applying auth.0012_alter_user_first_name_max_length... OK
    Applying sessions.0001_initial... OK

We'll also create an initial user named `admin`. We'll authenticate as that user later in our example.

    $ python manage.py createsuperuser --email admin@example.com --username admin
    Password: <enter your password>
    Password (again): <enter your password again>
    Superuser created successfully.

Once you've set up a database and the initial user is created and ready to go, open up the app's directory and we'll get coding...
