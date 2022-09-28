# RPA Address System

We're going to create a simple API to perform various types of search in the address system.

## Project setup

Copy the standard template for a python microservice.

    $ pwd
    <some path>/rpa-address-system
    $ find . -type f
    ./app/__init__.py
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
    ./tests/test_app_basics.py

    # Create a virtual environment to isolate our package dependencies locally
    export PIP_INDEX_URL="https://git.acmenet.ru/pypi/root/pypi/+simple/"
    export PIP_TRUSTED_HOST="git.acmenet.ru"
    make venv-init

    # Install linters, pytest and other general packages
    make venv-deps-upgrade

    # Save dependencies to 'requirements.txt' file (with versions)
    make venv-deps-freeze-and-save

After executing these commands, if you are working in VSCode, you need to restart the terminal.
