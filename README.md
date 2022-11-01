# RPA Address System

We're going to create a simple API to perform various types of search in the address system.

[[_TOC_]]

## Introduction

This manual is a compilation of the official [**Django REST framework Quickstart**](https://www.django-rest-framework.org/tutorial/quickstart/) and manuals for modules [`m3-gar`](https://pypi.org/project/m3-gar/) and [`m3-rest-gar`](https://pypi.org/project/m3-rest-gar/). Many thanks to the people who wrote them. I recommend reading these manuals before getting started.


## Django Project Setup

### Project setup

Copy the standard template for a python microservice.

```bash
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

# Create a virtual environment to isolate our package dependencies locally.
$ make venv-init
$ source .venv/bin/activate

# Install linters, pytest and other general packages.
$ make venv-deps-upgrade

# Save dependencies to 'requirements.txt' file (with versions).
$ make venv-deps-freeze-and-save
```

Create a new Django project named `app`, then start a new app called `gar`.

```bash
# Install Django and Django REST framework into the virtual environment
# Add `django==3.2.4`, `djangorestframework`, `m3-gar`, `m3-rest-gar` and `psycopg2-binary`
# to the `requirements.dev.txt` and then execute next commands:
$ make venv-deps-upgrade
$ make venv-deps-freeze-and-save

# Set up a new Django project with a single application.
$ django-admin startproject app .  # Don't forget about the trailing '.' character
$ cd app
$ django-admin startapp gar
$ cd ..
```

The project layout should look like:

```bash
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
```

### Environment Variables

Now let's move from the module `app/settings.py` sensitive data that should not get into the git repository. To do this, create a `.env` file in the root and move the lines to it

```bash
# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY="django-insecure-..."
# SECURITY WARNING: don't run with debug turned on in production!
DEBUG="0"  # 0 if False, 1 if True
# Specify the allowed hostnames or IP addresses separated by spaces.
ALLOWED_HOSTS="*"
```

And in the file `app/settings.py` instead of these lines we write

```python
from pathlib import Path
import os
from dotenv import load_dotenv

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent
dotenv_path = BASE_DIR / '.env'
if dotenv_path.exists():
    load_dotenv(dotenv_path)

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.environ.get('SECRET_KEY')

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = os.environ.get('DEBUG') == '1'

ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', '').split()
```


### Moving default SQLite database to data directory

By default, Django creates the default database in the root directory, this is not very convenient. Therefore, it is necessary to move the file `db.sqlite3` to the `data` folder and make the appropriate changes in the file `app/settings.py`:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'data' / 'db.sqlite3',
    },
}
```


### Moving default Django database to MySQL server

If you plan to place the default Django database on the MySQL/MariaDB server, then you need to perform the following actions.

#### Setting MySQL credentials in `.env` file for connecting to the MySQL/MariaDB DB:

```bash
DB_HOST="localhost"
DB_PORT="3306"
DB_NAME="Django"
DB_USER="DjangoUserName"
DB_PASS="DjangoPassWord"
```

#### Installing `pymysql` module in python virtual environment:

```bash
$ echo 'pymysql' >>requirements.dev.txt
$ make venv-deps-upgrade
$ make venv-deps-freeze-and-save
```

#### Updating `app/settings.py` file for connecting to the MySQL/MariaDB DB:

```python
import pymysql
pymysql.version_info = (1, 4, 6, 'final', 0)
pymysql.install_as_MySQLdb()
...
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'HOST': os.environ.get('DB_HOST'),
        'PORT': os.environ.get('DB_PORT'),
        'NAME': os.environ.get('DB_NAME'),
        'USER': os.environ.get('DB_USER'),
        'PASSWORD': os.environ.get('DB_PASS'),
    },
}
```


### Initializing Django DB and creating initial user `admin`

Now sync your database for the first time.

```bash
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
```

We'll also create an initial user named `admin`. We'll authenticate as that user later in our example.

```bash
$ python manage.py createsuperuser --email admin@example.com --username admin
Password: <enter your password>
Password (again): <enter your password again>
Superuser created successfully.
```

Once you've set up a database and the initial user is created and ready to go, open up the app's directory and we'll get coding...


### Serializers

First up we're going to define some serializers. Let's create a new module named `app/gar/serializers.py` that we'll use for our data representations.

```python
from django.contrib.auth.models import User, Group
from rest_framework import serializers


class UserSerializer(serializers.HyperlinkedModelSerializer):
    class Meta:
        model = User
        fields = ['url', 'username', 'email', 'groups']


class GroupSerializer(serializers.HyperlinkedModelSerializer):
    class Meta:
        model = Group
        fields = ['url', 'name']
```

Notice that we're using hyperlinked relations in this case with `HyperlinkedModelSerializer`. You can also use primary key and various other relationships, but hyperlinking is good RESTful design.


### Views

Right, we'd better write some views then. Open `app/gar/views.py` and get typing.

```python
from django.contrib.auth.models import User, Group
from rest_framework import permissions, viewsets

from app.gar.serializers import UserSerializer, GroupSerializer


class UserViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows users to be viewed or edited.
    """
    queryset = User.objects.all().order_by('-date_joined')
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]


class GroupViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows groups to be viewed or edited.
    """
    queryset = Group.objects.all()
    serializer_class = GroupSerializer
    permission_classes = [permissions.IsAuthenticated]
```

Rather than write multiple views we're grouping together all the common behavior into classes called `ViewSets`.

We can easily break these down into individual views if we need to, but using viewsets keeps the view logic nicely organized as well as being very concise.


### URLs

Okay, now let's wire up the API URLs. On to `app/urls.py`.

```python
from django.contrib import admin
from django.urls import include, path
from rest_framework import routers

from app.gar import views


router = routers.DefaultRouter()
router.register(r'users', views.UserViewSet)
router.register(r'groups', views.GroupViewSet)

# Wire up our API using automatic URL routing.
# Additionally, we include login URLs for the browsable API.
urlpatterns = [
    path('', include(router.urls)),
    path('admin/', admin.site.urls),
    path('api-auth/', include('rest_framework.urls', namespace='rest_framework')),
]
```

Because we're using viewsets instead of views, we can automatically generate the URL conf for our API, by simply registering the viewsets with a router class.

Again, if we need more control over the API URLs we can simply drop down to using regular class-based views, and writing the URL conf explicitly.

Finally, we're including default login and logout views for use with the browsable API. That's optional, but useful if your API requires authentication and you want to use the browsable API.


### Serving static files by Django in any debug-mode

In case you plan to run this instance of Django using gunicorn, you can add to the end of the file `app/urls.py` the following lines:

```python
# SECURITY WARNING: don't run with in real production!
# pylint: disable=wrong-import-position,wrong-import-order,ungrouped-imports
from django.contrib.staticfiles.urls import staticfiles_urlpatterns  # noqa
urlpatterns += staticfiles_urlpatterns()
```

This will allow Django to serve static files independently, without involving an external nginx server.


### Pagination

Pagination allows you to control how many objects per page are returned. To enable it add the following lines to `app/settings.py`:

```python
REST_FRAMEWORK = {
    'DEFAULT_FILTER_BACKENDS': [
        'django_filters.rest_framework.DjangoFilterBackend',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
}
if not DEBUG:
    REST_FRAMEWORK.update({
        'DEFAULT_RENDERER_CLASSES': (
            'rest_framework.renderers.JSONRenderer',
        )
    })
```

If you plan to use the `rest_framework` user interface, then the `DEBUG` variable in the `.env` file must be equal to `1`, otherwise files from the `/static/rest_framework/` folder will be unavailable to the browser. And the user interface will not work due to the fact that `rest_framework` will not be able to get `.css` and `.js` files. To avoid this, for the case when `DEBUG` is disabled, we write the default class `rest_framework.renderers.JSONRenderer` to the `DEFAULT_RENDERER_CLASSES` variable.


### Settings

Add `'rest_framework'` to `INSTALLED_APPS`. The settings module will be in `app/settings.py`:

```python
INSTALLED_APPS = [
    ...,
    'rest_framework',
]
```

Okay, we're done.


### Testing our API

We're now ready to test the API we've built. Let's fire up the server from the command line.

```bash
$ python manage.py runserver 0.0.0.0:8000
```

We can now access our API, both from the command-line, using tools like `curl`.

```bash
$ curl -H "Accept: application/json; indent=4" -u admin:"<password>" http://localhost:8000/users/
```
```json
{
    "count": 1,
    "next": null,
    "previous": null,
    "results": [
        {
            "url": "http://localhost:8000/users/1/",
            "username": "admin",
            "email": "admin@example.com",
            "groups": []
        }
    ]
}
```

Or directly through the browser, by going to the URL `http://localhost:8000/users/` in browser. In this case make sure to login using the control in the top right corner.


### Setting the permission policy

By default, REST API allowing unrestricted access. If there is a need to make authorization mandatory, you need to edit the file `app/settings.py`:

```python
REST_FRAMEWORK = {
    ...,
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    ...,
}
```


## `m3-gar` and `m3-rest-gar` project setup

### Setting up PostgreSQL server for GAR database

```bash
$ mkdir -p /srv/postgresql/data && cd /srv/postgresql/
$ nano docker-compose.yml
version: '3.6'
services:
  postgresql:
    image: 'postgres:13.8-alpine'
    container_name: postgresql
    restart: always
    environment:
      TZ: "Europe/Moscow"
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - 5432:5432
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ${PWD}/data:/var/lib/postgresql/data
$ nano .env
POSTGRES_DB="GAR"
POSTGRES_USER="GARUserName"
POSTGRES_PASSWORD="GARPassWord"
$ docker-compose up --detach
Creating network "postgresql_default" with the default driver
Creating postgresql ... done
```


### Setting up `m3-gar` and `m3-rest-gar` modules in Django project

Add some modules to `INSTALLED_APPS` and register modules and database in settings module will be in `app/settings.py`.

```python
INSTALLED_APPS = [
    ...,
    'django_filters',
    'm3_gar',
    'm3_rest_gar',
]

REST_FRAMEWORK = {
    ...,
    'DEFAULT_FILTER_BACKENDS': [
        'django_filters.rest_framework.DjangoFilterBackend',
    ],
}

GAR_DATABASE_ALIAS = 'gar'
DATABASES = {
    ...,
    GAR_DATABASE_ALIAS: {
        'ENGINE': 'django.db.backends.postgresql',
        'HOST': os.environ.get('GAR_DB_HOST'),
        'PORT': os.environ.get('GAR_DB_PORT'),
        'NAME': os.environ.get('GAR_DB_NAME'),
        'USER': os.environ.get('GAR_DB_USER'),
        'PASSWORD': os.environ.get('GAR_DB_PASS'),
    },
}

DATABASE_ROUTERS = [
    'm3_gar.routers.GARRouter',
]
```

```bash
$ nano .env
GAR_DB_HOST="localhost"
GAR_DB_PORT="5432"
GAR_DB_NAME="GAR"
GAR_DB_USER="GARUserName"
GAR_DB_PASS="GARPassWord"
```

Now let's register REST GAR API URL on to `app/urls.py`:

```python
urlpatterns = [
    ...,
    path('gar/', include('m3_rest_gar.urls')),
]
```

Now sync your database for using modules `m3-gar` and `m3-rest-gar`:

```bash
$ python manage.py migrate --database=gar
Operations to perform:
  Apply all migrations: admin, auth, contenttypes, m3_gar, sessions
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
  Applying m3_gar.0001_initial... OK
  Applying m3_gar.0002_auto_20210707_1352... OK
  Applying m3_gar.0003_auto_20210906_0744... OK
  Applying m3_gar.0004_auto_20211013_1106... OK
  Applying m3_gar.0005_auto_20211029_1212... OK
  Applying m3_gar.0006_auto_20211105_0937... OK
  Applying m3_gar.0007_version_processed... OK
  Applying m3_gar.0008_auto_20220217_0556... OK
  Applying m3_gar.0009_delete_status... OK
  Applying m3_gar.0010_auto_20220225_0934... OK
  Applying m3_gar.0011_auto_20220323_1022... OK
  Applying m3_gar.0012_auto_20220415_1452... OK
  Applying m3_gar.0013_auto_20220513_0825... OK
  Applying m3_gar.0014_addrobj_name_with_typename... OK
  Applying m3_gar.0015_alter_normativedocs_orgname... OK
  Applying sessions.0001_initial... OK

$ python manage.py migrate
Operations to perform:
  Apply all migrations: admin, auth, contenttypes, m3_gar, sessions
Running migrations:
  Applying m3_gar.0001_initial... OK
  Applying m3_gar.0002_auto_20210707_1352... OK
  Applying m3_gar.0003_auto_20210906_0744... OK
  Applying m3_gar.0004_auto_20211013_1106... OK
  Applying m3_gar.0005_auto_20211029_1212... OK
  Applying m3_gar.0006_auto_20211105_0937... OK
  Applying m3_gar.0007_version_processed... OK
  Applying m3_gar.0008_auto_20220217_0556... OK
  Applying m3_gar.0009_delete_status... OK
  Applying m3_gar.0010_auto_20220225_0934... OK
  Applying m3_gar.0011_auto_20220323_1022... OK
  Applying m3_gar.0012_auto_20220415_1452... OK
  Applying m3_gar.0013_auto_20220513_0825... OK
  Applying m3_gar.0014_addrobj_name_with_typename... OK
  Applying m3_gar.0015_alter_normativedocs_orgname... OK
```

In an ideal world, everything should work right away, but in the real world, a number of other procedures need to be performed. The following section contains hot fixes for errors that may occur.


### Fixing errors in `m3-gar` module

<details>
    <summary>Fixing error: <code>ImportError: cannot import name 'Mapping' from 'collections'</code></summary>

```python
$ python manage.py migrate --database=gar
Traceback (most recent call last):
File "/rpa-address-system/manage.py", line 22, in <module>
    main()
File "/rpa-address-system/manage.py", line 18, in main
    execute_from_command_line(sys.argv)
File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/core/management/__init__.py", line 419, in execute_from_command_line
    utility.execute()
File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/core/management/__init__.py", line 413, in execute
    self.fetch_command(subcommand).run_from_argv(self.argv)
File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/core/management/base.py", line 354, in run_from_argv
    self.execute(*args, **cmd_options)
File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/core/management/base.py", line 398, in execute
    output = self.handle(*args, **options)
File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/core/management/base.py", line 89, in wrapped
    res = handle_func(*args, **kwargs)
File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/core/management/commands/migrate.py", line 92, in handle
    executor = MigrationExecutor(connection, self.migration_progress_callback)
File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/migrations/executor.py", line 18, in __init__
    self.loader = MigrationLoader(self.connection)
File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/migrations/loader.py", line 53, in __init__
    self.build_graph()
File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/migrations/loader.py", line 214, in build_graph
    self.load_disk()
File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/migrations/loader.py", line 116, in load_disk
    migration_module = import_module(migration_path)
File "/usr/lib/python3.10/importlib/__init__.py", line 126, in import_module
    return _bootstrap._gcd_import(name[level:], package, level)
File "<frozen importlib._bootstrap>", line 1050, in _gcd_import
File "<frozen importlib._bootstrap>", line 1027, in _find_and_load
File "<frozen importlib._bootstrap>", line 1006, in _find_and_load_unlocked
File "<frozen importlib._bootstrap>", line 688, in _load_unlocked
File "<frozen importlib._bootstrap_external>", line 883, in exec_module
File "<frozen importlib._bootstrap>", line 241, in _call_with_frames_removed
File "/rpa-address-system/.venv/lib/python3.10/site-packages/m3_gar/migrations/0008_auto_20220217_0556.py", line 6, in <module>
    from m3_gar.importer.commands import get_table_names
File "/rpa-address-system/.venv/lib/python3.10/site-packages/m3_gar/importer/commands.py", line 39, in <module>
    from m3_gar.importer import (
File "/rpa-address-system/.venv/lib/python3.10/site-packages/m3_gar/importer/db_wrapper.py", line 2, in <module>
    from collections import (
ImportError: cannot import name 'Mapping' from 'collections' (/usr/lib/python3.10/collections/__init__.py)
```
```bash
$ sed -i 's/^from collections import/from collections.abc import/' `pip show m3-gar | grep 'Location' | sed -e 's/^Location: //'`/m3_gar/importer/db_wrapper.py
```

</details>

<details>
    <summary>Fixing error: <code>ProgrammingError: data type character varying has no default operator class for access method "gin"</code></summary>

```python
$ python manage.py migrate --database=gar
Operations to perform:
  Apply all migrations: admin, auth, contenttypes, m3_gar, sessions
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
  Applying m3_gar.0001_initial... OK
  Applying m3_gar.0002_auto_20210707_1352... OK
  Applying m3_gar.0003_auto_20210906_0744... OK
  Applying m3_gar.0004_auto_20211013_1106... OK
  Applying m3_gar.0005_auto_20211029_1212... OK
  Applying m3_gar.0006_auto_20211105_0937... OK
  Applying m3_gar.0007_version_processed... OK
  Applying m3_gar.0008_auto_20220217_0556... OK
  Applying m3_gar.0009_delete_status... OK
  Applying m3_gar.0010_auto_20220225_0934... OK
  Applying m3_gar.0011_auto_20220323_1022... OK
  Applying m3_gar.0012_auto_20220415_1452...Traceback (most recent call last):
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/backends/utils.py", line 82, in _execute
    return self.cursor.execute(sql)
psycopg2.errors.UndefinedObject: data type character varying has no default operator class for access method "gin"
HINT:  You must specify an operator class for the index or define a default operator class for the data type.


The above exception was the direct cause of the following exception:

Traceback (most recent call last):
  File "/rpa-address-system/manage.py", line 22, in <module>
    main()
  File "/rpa-address-system/manage.py", line 18, in main
    execute_from_command_line(sys.argv)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/core/management/__init__.py", line 419, in execute_from_command_line
    utility.execute()
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/core/management/__init__.py", line 413, in execute
    self.fetch_command(subcommand).run_from_argv(self.argv)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/core/management/base.py", line 354, in run_from_argv
    self.execute(*args, **cmd_options)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/core/management/base.py", line 398, in execute
    output = self.handle(*args, **options)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/core/management/base.py", line 89, in wrapped
    res = handle_func(*args, **kwargs)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/core/management/commands/migrate.py", line 244, in handle
    post_migrate_state = executor.migrate(
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/migrations/executor.py", line 117, in migrate
    state = self._migrate_all_forwards(state, plan, full_plan, fake=fake, fake_initial=fake_initial)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/migrations/executor.py", line 147, in _migrate_all_forwards
    state = self.apply_migration(state, migration, fake=fake, fake_initial=fake_initial)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/migrations/executor.py", line 227, in apply_migration
    state = migration.apply(state, schema_editor)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/migrations/migration.py", line 126, in apply
    operation.database_forwards(self.app_label, schema_editor, old_state, project_state)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/migrations/operations/models.py", line 761, in database_forwards
    schema_editor.add_index(model, self.index)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/backends/postgresql/schema.py", line 218, in add_index
    self.execute(index.create_sql(model, self, concurrently=concurrently), params=None)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/backends/base/schema.py", line 145, in execute
    cursor.execute(sql, params)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/backends/utils.py", line 98, in execute
    return super().execute(sql, params)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/backends/utils.py", line 66, in execute
    return self._execute_with_wrappers(sql, params, many=False, executor=self._execute)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/backends/utils.py", line 75, in _execute_with_wrappers
    return executor(sql, params, many, context)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/backends/utils.py", line 79, in _execute
    with self.db.wrap_database_errors:
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/utils.py", line 90, in __exit__
    raise dj_exc_value.with_traceback(traceback) from exc_value
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/backends/utils.py", line 82, in _execute
    return self.cursor.execute(sql)
django.db.utils.ProgrammingError: data type character varying has no default operator class for access method "gin"
HINT:  You must specify an operator class for the index or define a default operator class for the data type.
```
```bash
$ sed -i 's/^from django.contrib.postgres.operations import TrigramExtension/from django.contrib.postgres.operations import BtreeGinExtension, TrigramExtension/' `pip show m3-gar | grep 'Location' | sed -e 's/^Location: //'`/m3_gar/migrations/0012_auto_20220415_1452.py
$ sed -i 's/TrigramExtension(),/BtreeGinExtension(),\n        TrigramExtension(),/' `pip show m3-gar | grep 'Location' | sed -e 's/^Location: //'`/m3_gar/migrations/0012_auto_20220415_1452.py
```
</details>


### Fixing errors in `m3-rest-gar` module

<details>
    <summary>Fixing error: <code>django.core.exceptions.FieldError: Unsupported lookup 'exact' for CharField or join on the field not permitted</code></summary>

```python
Traceback (most recent call last):
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/core/handlers/exception.py", line 47, in inner
    response = get_response(request)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/core/handlers/base.py", line 181, in _get_response
    response = wrapped_callback(request, *callback_args, **callback_kwargs)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/views/decorators/csrf.py", line 54, in wrapped_view
    return view_func(*args, **kwargs)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/rest_framework/viewsets.py", line 125, in view
    return self.dispatch(request, *args, **kwargs)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/rest_framework/views.py", line 509, in dispatch
    response = self.handle_exception(exc)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/rest_framework/views.py", line 469, in handle_exception
    self.raise_uncaught_exception(exc)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/rest_framework/views.py", line 480, in raise_uncaught_exception
    raise exc
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/rest_framework/views.py", line 506, in dispatch
    response = handler(request, *args, **kwargs)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/rest_framework/mixins.py", line 38, in list
    queryset = self.filter_queryset(self.get_queryset())
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/rest_framework/generics.py", line 150, in filter_queryset
    queryset = backend().filter_queryset(self.request, queryset, self)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django_filters/rest_framework/backends.py", line 96, in filter_queryset
    return filterset.qs
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django_filters/filterset.py", line 243, in qs
    qs = self.filter_queryset(qs)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django_filters/filterset.py", line 230, in filter_queryset
    queryset = self.filters[name].filter(queryset, value)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django_filters/filters.py", line 146, in filter
    qs = self.get_method(qs)(**{lookup: value})
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/models/query.py", line 941, in filter
    return self._filter_or_exclude(False, args, kwargs)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/models/query.py", line 961, in _filter_or_exclude
    clone._filter_or_exclude_inplace(negate, args, kwargs)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/models/query.py", line 968, in _filter_or_exclude_inplace
    self._query.add_q(Q(*args, **kwargs))
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/models/sql/query.py", line 1391, in add_q
    clause, _ = self._add_q(q_object, self.used_aliases)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/models/sql/query.py", line 1410, in _add_q
    child_clause, needed_inner = self.build_filter(
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/models/sql/query.py", line 1345, in build_filter
    condition = self.build_lookup(lookups, col, value)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/models/sql/query.py", line 1176, in build_lookup
    lhs = self.try_transform(lhs, name)
  File "/rpa-address-system/.venv/lib/python3.10/site-packages/django/db/models/sql/query.py", line 1224, in try_transform
    raise FieldError(
django.core.exceptions.FieldError: Unsupported lookup 'exact' for CharField or join on the field not permitted, perhaps you meant exact or iexact?
[30/Oct/2022 12:46:25] "GET /gar/v1/addrobj/?level=&parent=&name=&name__exact=test&name_with_typename=&typename=&region_code=&name_with_parents= HTTP/1.1" 500 173632
```
```bash
$ patch `pip show m3-rest-gar | grep 'Location' | sed -e 's/^Location: //'`/m3_rest_gar/filters.py -p0 <./misc/m3-rest-gar-1.0.37/filters.patch
```
</details>


### Download and import GAR data from http://nalog.ru/ site

Now we are starting the longest procedures in terms of time. We need to download an archive with a database of addresses, extract the macro regions we need from them and upload them to the PostgreSQL database.

First, download the latest archive with the address database.

```bash
$ wget --directory-prefix=./data `curl -s https://fias.nalog.ru/WebServices/Public/GetLastDownloadFileInfo | jq -r '.GarXMLFullURL'`
--2022-09-29 09:52:24--  https://fias-file.nalog.ru/downloads/2022.09.27/gar_xml.zip
Resolving fias-file.nalog.ru... 93.93.89.87
Connecting to fias-file.nalog.ru|93.93.89.87|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 37221207752 (35G) [application/zip]
Saving to: 'gar_xml.zip'

gar_xml.zip     100%[=================================================>]  34.66G  10.6MB/s    in 56m 20s 

2022-09-29 10:48:44 (10.5 MB/s) - 'gar_xml.zip' saved [37221207752/37221207752]
```

If you plan to load a address directory for all macro-regions to the database, then you need to skip the next step. Otherwise, we will use the script to extract the macro-regions we need from the archive. In the `REGIONS` variable, it is necessary to list the macro-regions separated by a space, the data for which you want to extract.

```bash
$ REGIONS="47 78" ./misc/gar_xml_extract.sh ./data/gar_xml.zip ./data/_extracted
```

> Total size of data files for the two regions `47` and `78` will be `~12GiB`, after loading to the **PostgreSQL** database, the size of the database will be approximately the same. Keep in mind.

Now let's start loading the address directory into the database.

```bash
# To load the entire directory to PostgreSQL
$ python manage.py gar_load_data --src ./data/gar_xml.zip
# To load just extracted macro-regions
$ python manage.py gar_load_data --src ./data/_extracted/
```

> If there is already some data in the database, you need to add the key `--truncated`, otherwise the script will issue a corresponding message and stop working.

### Speed up GAR data loading to PostgreSQL

For initial data loading, it may be advantageous to temporarily disable database constraints and indexes and perform the loading without a transaction.

```bash
# Disabling all database restrictions and indexes
$ python manage.py manage_constraints disable --fk --unique --index --logged --commit
# Loading extracted macro-regions to PostgreSQL
$ python manage.py gar_load_data --no-truncate --no-transaction --src ./data/_extracted/
# Enabling all database restrictions and indexes
$ python manage.py manage_constraints enable --fk --unique --index --logged --commit
```

In an ideal world, everything should work right away, but in the real world it happens that files from different versions of the directory are found in the archive with the directory. And in some tables there are parts of addresses that refer to data that does not yet exist in older tables. In case of inconsistent data in the database, during the execution of the command <code>python manage.py manage_constraints enable ...</code> occur errors like this

```python
IntegrityError: insert or update on table "m3_gar_steads" violates foreign key constraint "m3_gar_steads_objectid_4d06fc6f_fk_m3_gar_re"
DETAIL:  Key (objectid)=(105589166) is not present in table "m3_gar_reestrobjects".
```

In order to be able to load data from such archives, it is necessary to apply a small patch for the `m3-gar` module.


### Patching `m3-gar` module for loading inconsistent archive data

This patch will remove rows from the database that refer to non-existent data. Thus, we will lose some addresses that have been added to the database in the last day or two, but the data in the database will remain consistent.

Before applying the patch, you need to make sure that the version of the `m3-gar` module is `1.0.33`.

```bash
$ pip show m3-gar | grep 'Version'
Version: 1.0.33
```

If the module version is suitable, then apply the patch:

```bash
$ patch `pip show m3-gar | grep 'Location' | sed -e 's/^Location: //'`/m3_gar/management/commands/manage_constraints.py -p0 <./misc/m3-gar-1.0.33/manage_constraints.patch
patching file /rpa-address-system/.venv/lib/python3.10/site-packages/m3_gar/management/commands/manage_constraints.py
```

After applying the patch, let's start the process of loading data to the database. Note that to the last command we added the key `--delete-key-violations-quick`, which appeared after applying the patch. This command deletes inconsistent data when creating indexes and relationships in database tables.

```bash
# Disabling all database restrictions and indexes
$ python manage.py manage_constraints disable --fk --unique --index --logged --commit

# Loading extracted macro-regions to PostgreSQL
$ python manage.py gar_load_data --no-truncate --no-transaction --src ./data/_extracted/
...
Awaiting pending database write tasks
6160 out of 6160 tasks done
Unknown uploaded version. Please set attribute processed=True to all instances of Version model that less or equal to uploaded version yourself, or next update will be more time consuming
Data v.20220923 from 2022-09-23 loaded at 2022-09-29 22:21:55.572804+00:00
Estimated time: 4:44:44.273604. Download: 0. Unpack: 0. Import: 4:44:43.628321

# Enabling all database restrictions and indexes
$ python manage.py manage_constraints enable --fk --unique --index --logged --commit --delete-key-violations-quick
...
DELETE FROM m3_gar_steads WHERE objectid >= 105589166;
DELETE FROM m3_gar_munhierarchy WHERE objectid >= 105589166;
DELETE FROM m3_gar_carplaces WHERE objectid >= 105590959;
DELETE FROM m3_gar_admhierarchy WHERE objectid >= 105589166;
DELETE FROM m3_gar_apartments WHERE objectid >= 105590250;
DELETE FROM m3_gar_houses WHERE objectid >= 105589510;
Total deleted row count: 2378
```

> Loading two regions `47` and `78` takes a little less than 5 hours on a computer with an NVMe SSD, 64GB of RAM and a Quad-core `i7-8559U` processor.


### Filling `name_with_parents` and `name_with_typename` fields in the `AddrOdj` model

Additional fields `name_with_parents` (in the hierarchy model) and `name_with_typename` (in the `AddrOdj` model) were added to the database. To fill these fields with data, the `fill_custom_fields` command is provided.

```python
# Starting updating the name_with_parents fields for the AdmHierarchy and MunHierarchy models
$ python manage.py fill_custom_fields --parents --levels=1,2,3,4,5,6,7,8 --adm
$ python manage.py fill_custom_fields --parents --levels=1,2,3,4,5,6,7,8
# Starting updating the name_with_typename fields for the AddrObj model (for 7,8 levels only)
$ python manage.py fill_custom_fields --typenames
```


### Testing our `m3-rest-gar` API

We're now ready to test the `m3-rest-gar` API we've built. Let's fire up the server from the command line.

```bash
$ python manage.py runserver 0.0.0.0:8000
```

We can now access our API, both from the command-line, using tools like `curl`.

```bash
$ curl -H "Accept: application/json; indent=4" -u admin:"<password>" "http://localhost:8000/gar/v1/"
```
```json
{
    "addrobj": "http://localhost:8000/gar/v1/addrobj/",
    "houses": "http://localhost:8000/gar/v1/houses/",
    "steads": "http://localhost:8000/gar/v1/steads/",
    "apartments": "http://localhost:8000/gar/v1/apartments/",
    "rooms": "http://localhost:8000/gar/v1/rooms/"
}
```

Here we see what methods are available for this REST API. Let's try to call `addrobj` with the `level=1` parameter (show only the list of macro-regions):

```bash
$ curl -s -H "Accept: application/json" -u admin:"<password>" "http://localhost:8000/gar/v1/addrobj/?level=1" | jq -r '.results[] | [.region_code, .name] | @csv'
47,"Ленинградская"
78,"Санкт-Петербург"
```

You can open the URL `http://localhost:8000/gar/v1/` directly in the browser so that you can perform various types of search with filtering. In this case make sure to login using the control in the top right corner.

More detailed information about the types of search with examples can be found on the official module page [`m3-rest-gar`](https://pypi.org/project/m3-rest-gar/).
