.DEFAULT_GOAL := help
SHELL := /bin/bash


##@ A group of targets

.PHONY: root-target  ## I have no dependencies
root-target:
	$(info root-target)
	@ls

.PHONY: no-recipes  ## I have no effective recipes
no-recipes: root-target
	$(info no-recipes)
	@# Note: This target has no effective recipes (besides printing text)

.PHONY: two-hashes-comment  ## I am listed in `make help` and highlighted bluish
two-hashes-comment: no-recipes
	$(info two-hashes-comment)
	@ls


##@ Another group

.PHONY: foo
foo:
	@ls

.PHONY: bar  # I have a simple comment
bar: foo
	@ls

.PHONY: ordered  ## I have multiple dependencies
ordered: no-recipes bar
	@ls


##@ Misc

# Inspired by https://suva.sh/posts/well-documented-makefiles/
.PHONY: help  ## Display this help
help:
	@# if you have the comments on the target declaration:
	@#awk 'BEGIN {FS = "[[:blank:]]*:.*##[[:blank:]]*"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^[^[:blank:]=#]+:.*?##/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2} /^##@[[:blank:]]/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)}' $(MAKEFILE_LIST)
	@# if you have the comments on the phony declaration:
	@awk 'BEGIN {FS = "(\\.PHONY:[[:blank:]]*|[[:blank:]]*##[[:blank:]]*)"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^\.PHONY:[[:blank:]]*[^[:blank:]#]+[[:blank:]]*##/ {printf "  \033[36m%-20s\033[0m %s\n", $$2, $$3} /^##@[[:blank:]]/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)}' $(MAKEFILE_LIST)
