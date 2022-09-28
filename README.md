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
    # Add `django==3.2.4`, `djangorestframework`, `m3-gar`, `m3-rest-gar` and
    # `psycopg2-binary` to the `requirements.dev.txt` and then execute next commands:
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

## Serializers

First up we're going to define some serializers. Let's create a new module named `app/gar/serializers.py` that we'll use for our data representations.

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

Notice that we're using hyperlinked relations in this case with `HyperlinkedModelSerializer`.  You can also use primary key and various other relationships, but hyperlinking is good RESTful design.

## Views

Right, we'd better write some views then.  Open `app/gar/views.py` and get typing.

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

Rather than write multiple views we're grouping together all the common behavior into classes called `ViewSets`.

We can easily break these down into individual views if we need to, but using viewsets keeps the view logic nicely organized as well as being very concise.

## URLs

Okay, now let's wire up the API URLs.  On to `app/urls.py`...

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

Because we're using viewsets instead of views, we can automatically generate the URL conf for our API, by simply registering the viewsets with a router class.

Again, if we need more control over the API URLs we can simply drop down to using regular class-based views, and writing the URL conf explicitly.

Finally, we're including default login and logout views for use with the browsable API.  That's optional, but useful if your API requires authentication and you want to use the browsable API.

## Pagination

Pagination allows you to control how many objects per page are returned. To enable it add the following lines to `app/settings.py`

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

## Settings

Add `'rest_framework'` to `INSTALLED_APPS`. The settings module will be in `app/settings.py`

    INSTALLED_APPS = [
        ...
        'rest_framework',
    ]

Okay, we're done.

## Environment Variables

Now let's move from the module `app/settings.py` sensitive data that should not get into the git repository. To do this, create a `.env` file in the root and move the lines to it

    # SECURITY WARNING: keep the secret key used in production secret!
    SECRET_KEY="django-insecure-..."

    # SECURITY WARNING: don't run with debug turned on in production!
    DEBUG="0"  # 0 if False, 1 if True

    ALLOWED_HOSTS="*"  # Specify the allowed hostnames or IP addresses separated by spaces

And in the file `app/settings.py` instead of these lines we write

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

If you plan to use the `rest_framework` user interface, then the `DEBUG` variable in the `.env` file must be equal to "1", otherwise files from the `/static/rest_framework/` folder will be unavailable to the browser. And the user interface will not work due to the fact that `rest_framework` will not be able to get `.css` and `.js` files. To avoid this, for the case when `DEBUG` is disabled, we write the default class `rest_framework.renderers.JSONRenderer` to the `DEFAULT_RENDERER_CLASSES` variable.

---

## Testing our API

We're now ready to test the API we've built.  Let's fire up the server from the command line.

    $ python manage.py runserver 0.0.0.0:8000

We can now access our API, both from the command-line, using tools like `curl`...

    $ curl -H "Accept: application/json; indent=4" -u admin:"<our password>" http://127.0.0.1:8000/users/
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

Or directly through the browser, by going to the URL `http://127.0.0.1:8000/users/` in browser. In this case make sure to login using the control in the top right corner.
