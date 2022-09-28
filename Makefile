# *** ACME Laboratories default Makefile for python projects ***

APP := app
MISC := misc
VENV := .venv
ACTIVATE := @. $(VENV)/bin/activate
MAKEFLAGS += --no-print-directory

# Importing environment variables from $ENV file if it exists
#ENV := .env
#ifeq ("$(shell test -e $(ENV) && echo OK)","OK")
#$(eval include $(ENV))
#$(eval export $(shell sed 's/=.*//' $(ENV) | grep -v '#'))
#endif

# *** GENERAL ***

.PHONY: help
.DEFAULT_GOAL := help
help:  ## Show make help
	@grep --no-filename --color=never -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	| awk 'BEGIN { FS = ":.*?## " }; { printf "\033[36m%-30s\033[0m %s\n", $$1, $$2 }' \
	| sort

.PHONY: run
run:  ## Run main.py program
ifeq ("$(shell test -e main.py && echo OK)","OK")
	$(ACTIVATE) && python main.py
else
	@make help
	@echo "ERROR: main.py program not found, try another target 'make run-*'..."
endif

REQUIREMENTS_APT := requirements.apt.txt
ifeq ("$(shell test -e $(REQUIREMENTS_APT) && echo OK)","OK")
APT_LIST := $(shell sed '/^[[:blank:]]*\#/d;s/\#.*//' $(REQUIREMENTS_APT) | xargs -r echo)
else
APT_LIST := 
endif
.PHONY: apt-deps-install
apt-deps-install:  ## Install system dependencies from 'requirements.apt.txt'
ifneq ($(APT_LIST),)
	@export DEBIAN_FRONTEND="noninteractive"; \
	apt-get install -y --quiet --no-install-recommends $(APT_LIST)
else
	@echo "ERROR: file $(REQUIREMENTS_APT) not found or empty, nothing to install..."
endif

# *** CLEAN ***

.PHONY: clean
clean:  ## Remove all build, test and coverage Python artifacts
	@find . -name '__pycache__' -type d | xargs rm -rf
	@find . -name '*.pyc' -type f | xargs rm -f
	@find . -name '.pytest_cache' -type d | xargs rm -rf
	@find . -name '*.pytest_cache' -type d | xargs rm -rf
	@find . -name '.coverage' -type f | xargs rm -f

# *** VIRTUAL ENVIRONMENT  ***

.PHONY: venv-activate
venv-activate:  ## Activate Virtual Environment
	$(ACTIVATE) && exec /usr/bin/env bash

.PHONY: venv-init
venv-init:  ## Init Virtual Environment
	@/usr/bin/env python3 -m venv $(VENV)
	@make venv-upgrade

# Importing PIP_* environment variables from $ENV file if it exists
#ENV := .env
#ifeq ("$(shell test -e $(ENV) && echo OK)","OK")
#$(eval include $(ENV))
#$(eval export $(shell sed 's/=.*//' $(ENV) | grep '^PIP_'))
#endif
.PHONE: venv-init-pip-conf
venv-init-pip-conf:
ifneq ($(http_proxy),)
	@echo "Set proxy $(http_proxy) in $(VENV)/pip.conf"
	$(ACTIVATE) && pip config set --site global.proxy $(http_proxy) >/dev/null
else
	$(ACTIVATE) && pip config unset --site global.proxy >/dev/null 2>&1 || true
endif
ifneq ($(PIP_INDEX_URL),)
	@echo "Set index-url $(PIP_INDEX_URL) in $(VENV)/pip.conf"
	$(ACTIVATE) && pip config set --site global.timeout 120 >/dev/null
	$(ACTIVATE) && pip config set --site global.index-url $(PIP_INDEX_URL) >/dev/null
else
	$(ACTIVATE) && pip config unset --site global.timeout >/dev/null 2>&1 || true
	$(ACTIVATE) && pip config unset --site global.index-url >/dev/null 2>&1 || true
endif
ifneq ($(PIP_TRUSTED_HOST),)
	@echo "Set trusted-host $(PIP_TRUSTED_HOST) in $(VENV)/pip.conf"
	$(ACTIVATE) && pip config set --site global.trusted-host $(PIP_TRUSTED_HOST) >/dev/null
else
	$(ACTIVATE) && pip config unset --site global.trusted-host >/dev/null 2>&1 || true
endif

.PHONY: venv-remove
	@rm -rf ./$(VENV)

.PHONY: venv-upgrade
venv-upgrade:  ## Upgrade Virtual Environment
	@make venv-init-pip-conf
	$(ACTIVATE) && pip install --upgrade pip setuptools wheel

.PHONY: venv-deps-freeze-and-save
venv-deps-freeze-and-save:  ## Save dependencies to 'requirements.txt' file (with versions)
	$(ACTIVATE) && pip freeze | grep -v -- '^-e' >requirements.txt

.PHONY: venv-deps-install
venv-deps-install:  ## Install dependencies from 'requirements.txt' file (with versions)
	$(ACTIVATE) && pip install -r requirements.txt

.PHONY: venv-deps-upgrade
venv-deps-upgrade:  ## Upgrade dependencies from 'requirements.dev.txt' file (no versions)
	$(ACTIVATE) && pip install --upgrade -r requirements.dev.txt

# *** TEST ***

PYTEST_ARGS := --verbose --rootdir tests
.PHONY: test
test:  ## Runs tests
	$(ACTIVATE) && pytest $(PYTEST_ARGS) -W ignore

.PHONY: test-coverage
test-coverage:  ## Runs tests with coverage
	$(ACTIVATE) && pytest $(PYTEST_ARGS) -W ignore --cov --cov-config tests/.coveragerc

.PHONY: test-show-warnings
test-show-warnings:  ## Runs tests with show warnings
	$(ACTIVATE) && pytest $(PYTEST_ARGS) -W default

# *** LINT ***

# Create list of *.py files for linters
LINT_FIND_ARGS := -iname "*.py" \
	! -path "./$(VENV)*/*" \
	! -path "./data/*" \
	! -path "./migrations/*" \
	! -path "./misc/*"
LINT_FILE_LIST := $(shell find . -type f $(LINT_FIND_ARGS) | sort)

LINT_FLAKE8_CONFIG := "$(MISC)/.flake8"
LINT_FLAKE8_ARGS := --exit-zero
ifeq ("$(shell test -e $(LINT_FLAKE8_CONFIG) && echo OK)","OK")
LINT_FLAKE8_ARGS += --append-config $(LINT_FLAKE8_CONFIG)
endif
.PHONY: lint-flake8
lint-flake8:  ## Linting with flake8
	$(ACTIVATE) && flake8 $(LINT_FLAKE8_ARGS) $(LINT_FILE_LIST)

LINT_PYLINT_CONFIG := "$(MISC)/.pylintrc"
LINT_PYLINT_ARGS := --exit-zero --output-format=colorized
ifeq ("$(shell test -e $(LINT_PYLINT_CONFIG) && echo OK)","OK")
LINT_PYLINT_ARGS += --rcfile=$(LINT_PYLINT_CONFIG)
endif
.PHONY: lint-pylint
lint-pylint:  ## Linting with pylint
	$(ACTIVATE) && pylint $(LINT_PYLINT_ARGS) $(LINT_FILE_LIST)

.PHONY: lint
lint: lint-flake8 lint-pylint  ## Run all lint type scripts

# Importing additional Makefiles (for flask, django or docker targets)
ifeq ("$(shell ls $(MISC)/Makefile.*.mk >/dev/null 2>&1 && echo OK)","OK")
$(eval include $(MISC)/Makefile.*.mk)
endif
