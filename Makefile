.PHONY: bootstrap graphify-init graphify-update metrics-report churn-report

# ── Bootstrap ──────────────────────────────────────────────────────────────────
# Usage: make bootstrap PROJECT=my-project-name
bootstrap:
ifndef PROJECT
	$(error PROJECT is required. Usage: make bootstrap PROJECT=my-project)
endif
	bash scripts/bootstrap.sh $(PROJECT)

# ── Graphify ───────────────────────────────────────────────────────────────────
# Initialize graphify for the current project (run once per sub-project)
graphify-init:
	bash scripts/graphify-update.sh init

# Update graph after code changes
graphify-update:
	bash scripts/graphify-update.sh

# ── Metrics ───────────────────────────────────────────────────────────────────
# Generate session metrics report
metrics-report:
	bash scripts/metric-logger.sh report

# Generate per-feature AI vs human comparison
# Usage: make churn-report FEATURE=my-feature
churn-report:
ifndef FEATURE
	$(error FEATURE is required. Usage: make churn-report FEATURE=my-feature)
endif
	bash scripts/metric-logger.sh feature-report $(FEATURE)
