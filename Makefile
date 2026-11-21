# Dev helpers — run `make check` before committing.

SCRIPTS := scripts/setup-print-server.sh scripts/load-firmware.sh scripts/diagnostics.sh

.PHONY: check lint syntax

check: syntax lint

syntax:
	bash -n $(SCRIPTS)

lint:
	shellcheck -x $(SCRIPTS)
