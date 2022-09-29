# RPA Address System

We're going to create a simple API to perform various types of search in the address system.

[[_TOC_]]

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

# Create a virtual environment to isolate our package dependencies locally
$ export PIP_INDEX_URL="https://git.acmenet.ru/pypi/root/pypi/+simple/"
$ export PIP_TRUSTED_HOST="git.acmenet.ru"
$ make venv-init
$ source .venv/bin/activate

# Install linters, pytest and other general packages
$ make venv-deps-upgrade

# Save dependencies to 'requirements.txt' file (with versions)
$ make venv-deps-freeze-and-save
```

Create a new Django project named `app`, then start a new app called `gar`.

```bash
# Install Django and Django REST framework into the virtual environment
# Add `django==3.2.4`, `djangorestframework`, `m3-gar`, `m3-rest-gar` and
# `psycopg2-binary` to the `requirements.dev.txt` and then execute next commands:
$ make venv-deps-upgrade
$ make venv-deps-freeze-and-save

# Set up a new Django project with a single application
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

Now sync your database for the first time:

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

Notice that we're using hyperlinked relations in this case with `HyperlinkedModelSerializer`.  You can also use primary key and various other relationships, but hyperlinking is good RESTful design.


### Views

Right, we'd better write some views then.  Open `app/gar/views.py` and get typing.

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

Okay, now let's wire up the API URLs.  On to `app/urls.py`...

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

Finally, we're including default login and logout views for use with the browsable API.  That's optional, but useful if your API requires authentication and you want to use the browsable API.


### Pagination

Pagination allows you to control how many objects per page are returned. To enable it add the following lines to `app/settings.py`

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


### Settings

Add `'rest_framework'` to `INSTALLED_APPS`. The settings module will be in `app/settings.py`

```python
INSTALLED_APPS = [
    ...,
    'rest_framework',
]
```

Okay, we're done.


### Environment Variables

Now let's move from the module `app/settings.py` sensitive data that should not get into the git repository. To do this, create a `.env` file in the root and move the lines to it

```bash
# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY="django-insecure-..."

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG="0"  # 0 if False, 1 if True

ALLOWED_HOSTS="*"  # Specify the allowed hostnames or IP addresses separated by spaces
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

If you plan to use the `rest_framework` user interface, then the `DEBUG` variable in the `.env` file must be equal to `1`, otherwise files from the `/static/rest_framework/` folder will be unavailable to the browser. And the user interface will not work due to the fact that `rest_framework` will not be able to get `.css` and `.js` files. To avoid this, for the case when `DEBUG` is disabled, we write the default class `rest_framework.renderers.JSONRenderer` to the `DEFAULT_RENDERER_CLASSES` variable.


### Testing our API

We're now ready to test the API we've built.  Let's fire up the server from the command line.

```bash
$ python manage.py runserver 0.0.0.0:8000
```

We can now access our API, both from the command-line, using tools like `curl`...

```bash
$ curl -H "Accept: application/json; indent=4" -u admin:"<password>" http://127.0.0.1:8000/users/
```
```json
{
    "count": 1,
    "next": null,
    "previous": null,
    "results": [
        {
            "url": "http://127.0.0.1:8000/users/1/",
            "username": "admin",
            "email": "admin@example.com",
            "groups": []
        }
    ]
}
```

Or directly through the browser, by going to the URL `http://127.0.0.1:8000/users/` in browser. In this case make sure to login using the control in the top right corner.


## m3-gar and m3-rest-gar project setup

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


### Setting up m3-gar and m3-rest-gar modules in Django project

Add some modules to `INSTALLED_APPS` and register modules and database in settings module will be in `app/settings.py`.

```python
INSTALLED_APPS = [
    ...,
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

Now let's register REST GAR API URL on to `app/urls.py`

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


### Fixing errors in m3-gar module

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
$ sed -i 's/^from collections import/from collections.abc import/' .venv/lib/python3.10/site-packages/m3_gar/importer/db_wrapper.py
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
$ sed -i 's/^from django.contrib.postgres.operations import TrigramExtension/from django.contrib.postgres.operations import BtreeGinExtension, TrigramExtension/' .venv/lib/python3.10/site-packages/m3_gar/migrations/0012_auto_20220415_1452.py
$ sed -i 's/TrigramExtension(),/BtreeGinExtension(),\n        TrigramExtension(),/' .venv/lib/python3.10/site-packages/m3_gar/migrations/0012_auto_20220415_1452.py
```
</details>
