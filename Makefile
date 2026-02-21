# ClawEx Hot Upgrade Makefile
# Zero-downtime code swap via OTP releases — without disconnecting any clients.

APP     := claw_ex
VERSION := $(shell grep 'version:' mix.exs | head -1 | sed 's/.*"\(.*\)".*/\1/')
REL_DIR := _build/prod/rel/$(APP)

.PHONY: help build upgrade rollback status

help:
	@echo "ClawEx release targets:"
	@echo "  make build    — build a production release tarball"
	@echo "  make upgrade  — hot-upgrade a running node to VERSION=$(VERSION)"
	@echo "  make status   — show running release version"
	@echo ""
	@echo "Hot upgrade workflow:"
	@echo "  1. Bump version in mix.exs"
	@echo "  2. make build"
	@echo "  3. make upgrade"
	@echo "  → running node swaps code with zero downtime, sessions stay alive"

build:
	MIX_ENV=prod mix deps.get --only prod
	MIX_ENV=prod mix compile
	MIX_ENV=prod mix release --overwrite
	@echo "✅ Release built: $(REL_DIR)/releases/$(VERSION)/$(APP).tar.gz"

upgrade:
	@echo "→ Uploading and hot-upgrading to v$(VERSION)..."
	$(REL_DIR)/bin/$(APP) upgrade "$(VERSION)"
	@echo "✅ Hot upgrade complete — nodes still connected, sessions alive"

rollback:
	@if [ -z "$(TO)" ]; then echo "Usage: make rollback TO=<version>"; exit 1; fi
	$(REL_DIR)/bin/$(APP) downgrade "$(TO)"
	@echo "✅ Rolled back to v$(TO)"

status:
	$(REL_DIR)/bin/$(APP) remote "IO.puts System.version()"

# ── Docker (optional) ─────────────────────────────────────────────────────────
docker-build:
	docker build -t $(APP):$(VERSION) .

docker-run:
	docker run -p 4000:4000 --env-file .env $(APP):$(VERSION)
