.DEFAULT_GOAL := help
SHELL := /bin/bash


##@ A group of targets
.PHONY: simple-comment example-target-2

root-target:  ## I have no dependencies
	$(info root-target)
	@ls

no-recipes: root-target  ## I have no effective recipes
	$(info no-recipes)
	@# Note: This target has no effective recipes (besides printing text)

two-hashes-comment: no-recipes  ## I am listed in `make help` and highlighted bluish
	$(info two-hashes-comment)
	@ls


##@ Another group
.PHONY: foo ordered

foo:
	@ls

bar: foo  # I have a simple comment
	@ls

ordered: no-recipes bar  ## I have multiple dependencies
	@ls


##@ Misc
.PHONY: help

# From https://suva.sh/posts/well-documented-makefiles/
# But changed `[a-zA-Z_-]` to `[^\t #]` in the regex below.
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^[^\t #]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
