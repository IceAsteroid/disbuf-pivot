# Run the checks for display-buffer-pivot.

EMACS ?= emacs
ELPA ?= $(HOME)/.emacs.d/elpa

ACE_WINDOW := $(firstword $(wildcard $(ELPA)/ace-window-*))
AVY := $(firstword $(wildcard $(ELPA)/avy-*))
CONSULT := $(firstword $(wildcard $(ELPA)/consult-*))

LOAD_PATH = -L . -L $(ACE_WINDOW) -L $(AVY)

# The optional consult library is checked by `check-consult', not by
# `check', so the required checks do not need consult.
FILES = $(wildcard *.el)
CONSULT_FILES = display-buffer-pivot-tab-bar-consult.el
CHECK_FILES = $(filter-out $(CONSULT_FILES),$(FILES))

.PHONY: all check check-consult check-deps check-deps-consult \
        compile compile-consult checkdoc checkdoc-consult test

all: check

check: compile test

check-consult: check-deps-consult compile-consult checkdoc-consult

check-deps:
	@for dir in "$(ACE_WINDOW)" "$(AVY)"; do \
		test -n "$$dir" || { \
			printf '%s\n' "missing a dependency under $(ELPA)"; exit 1; }; \
	done

check-deps-consult: check-deps
	@test -n "$(CONSULT)" || { \
		printf '%s\n' "missing consult under $(ELPA)"; exit 1; \
	}

compile: check-deps
	@tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
	cp $(CHECK_FILES) "$$tmp"/; \
	$(EMACS) -Q --batch -L "$$tmp" -L $(ACE_WINDOW) -L $(AVY) \
		-f batch-byte-compile "$$tmp"/*.el

compile-consult: check-deps-consult
	@tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
	cp $(CHECK_FILES) $(CONSULT_FILES) "$$tmp"/; \
	$(EMACS) -Q --batch -L "$$tmp" -L $(ACE_WINDOW) -L $(AVY) \
		-L $(CONSULT) -f batch-byte-compile \
		"$$tmp"/$(CONSULT_FILES)

checkdoc: check-deps
	@for file in $(CHECK_FILES); do \
		printf '== %s\n' "$$file"; \
		$(EMACS) -Q --batch $(LOAD_PATH) \
			--eval "(progn (require 'checkdoc) (checkdoc-file \"$$file\"))"; \
	done

checkdoc-consult: check-deps-consult
	@for file in $(CONSULT_FILES); do \
		printf '== %s\n' "$$file"; \
		$(EMACS) -Q --batch $(LOAD_PATH) -L $(CONSULT) \
			--eval "(progn (require 'checkdoc) (checkdoc-file \"$$file\"))"; \
	done

test:
	eldev test
