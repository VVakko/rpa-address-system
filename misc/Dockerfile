FROM python:3.12-slim-bullseye

LABEL maintainer="Alexander Protasov <protasov_aa@pesc.ru>"
LABEL application="RPA Address System"

# Configure system environment
ENV LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    PYTHONDONTWRITEBYTECODE="1" \
    PYTHONUNBUFFERED="1"

# Configure corporate mirrors for ubuntu, pypi and other software
ARG APT_MIRROR
ARG GIT_SSL_NO_VERIFY
ARG PIP_INDEX_URL
ARG PIP_TRUSTED_HOST

# Select Yandex mirror, install system dependencies and create user rpa
RUN if [ ! -z "$APT_MIRROR" ]; then \
    . /etc/os-release \
    && export APT_SOURCES="/etc/apt/sources.list" \
    && mv $APT_SOURCES $APT_SOURCES.bak \
    && echo "deb $APT_MIRROR/debian $VERSION_CODENAME main" >>$APT_SOURCES \
    && echo "deb $APT_MIRROR/debian $VERSION_CODENAME-updates main" >>$APT_SOURCES \
    && echo "deb $APT_MIRROR/debian-security $VERSION_CODENAME-security main" >>$APT_SOURCES; \
fi
RUN    export DEBIAN_FRONTEND="noninteractive" \
    && cat /etc/apt/sources.list \
    && apt-get update && apt-get upgrade -y --quiet \
    && apt-get install -y --quiet --no-install-recommends \
        build-essential curl git-core make python3-dev python3-venv

# Configure filesystem
RUN mkdir /application
WORKDIR /application
COPY app ./app
COPY misc ./misc
COPY .env *.py requirements.* Makefile ./

# Install application dependencies and prepare application Virtual Environment
RUN    make apt-deps-install \
    && make venv-init \
    && make venv-deps-install \
    && make venv-deps-patch \
    && apt-get clean && apt-get purge -y --auto-remove gcc git-core python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Create entrypoint.sh, add user and chown /application folder with contents
RUN printf "#!/bin/sh\n\
make run-django-migrate\n\
make run-django-supervisord\n" >entrypoint.sh \
    && chmod u+x entrypoint.sh \
    && adduser rpa --no-create-home --gecos "" --disabled-password \
    && chown -R rpa: /application

# Configure application environment and deploy
# Configure application environment and deploy
ENV GUNICORN_BIND_HOST="0.0.0.0" \
    GUNICORN_BIND_PORT="8000" \
    GUNICORN_LIMIT_REQUEST_FIELD_SIZE="0" \
    GUNICORN_LIMIT_REQUEST_LINE="0" \
    GUNICORN_TIMEOUT="60" \
    GUNICORN_WORKERS="1"
ENV GUNICORN_CMD_ARGS=$"\
    --bind ${GUNICORN_BIND_HOST}:${GUNICORN_BIND_PORT} \
    --limit-request-field_size ${GUNICORN_LIMIT_REQUEST_FIELD_SIZE} \
    --limit-request-line ${GUNICORN_LIMIT_REQUEST_LINE} \
    --timeout ${GUNICORN_TIMEOUT} \
    --workers ${GUNICORN_WORKERS} \
"
USER rpa
ENTRYPOINT [ "./entrypoint.sh" ]
