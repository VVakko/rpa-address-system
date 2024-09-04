# *** m3-gar ***

.PHONY: venv-deps-patch
venv-deps-patch:  # Patch m3-gar module (don't show this menu in make main menu)
	$(ACTIVATE) && sed -i 's/^from collections import/from collections.abc import/' `pip show m3-gar | grep 'Location' | sed -e 's/^Location: //'`/m3_gar/importer/db_wrapper.py
	$(ACTIVATE) && sed -i 's/^from django.contrib.postgres.operations import TrigramExtension/from django.contrib.postgres.operations import BtreeGinExtension, TrigramExtension/' `pip show m3-gar | grep 'Location' | sed -e 's/^Location: //'`/m3_gar/migrations/0012_auto_20220415_1452.py
	$(ACTIVATE) && sed -i 's/TrigramExtension(),/BtreeGinExtension(),\n        TrigramExtension(),/' `pip show m3-gar | grep 'Location' | sed -e 's/^Location: //'`/m3_gar/migrations/0012_auto_20220415_1452.py
	$(ACTIVATE) && patch `pip show m3-gar | grep 'Location' | sed -e 's/^Location: //'`/m3_gar/management/commands/manage_constraints.py -p0 <./misc/m3-gar-1.1.1/manage_constraints.patch
	$(ACTIVATE) && patch `pip show m3-rest-gar | grep 'Location' | sed -e 's/^Location: //'`/m3_rest_gar/filters.py -p0 <./misc/m3-rest-gar-1.0.45/filters.patch
