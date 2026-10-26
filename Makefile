# Run the checks for display-buffer-pivot.

EMACS ?= emacs
ELPA ?= $(HOME)/.emacs.d/elpa

ACE_WINDOW := $(firstword $(wildcard $(ELPA)/ace-window-*))
AVY := $(firstword $(wildcard $(ELPA)/avy-*))

LOAD_PATH = -L . -L $(ACE_WINDOW) -L $(AVY)

FILES = $(wildcard *.el)
CHECK_FILES = $(FILES)

.PHONY: all check check-deps compile checkdoc test

all: check

check: compile test

check-deps:
	@for dir in "$(ACE_WINDOW)" "$(AVY)"; do \
		test -n "$$dir" || { \
			printf '%s\n' "missing a dependency under $(ELPA)"; exit 1; }; \
	done

compile: check-deps
	@tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
	cp $(CHECK_FILES) "$$tmp"/; \
	$(EMACS) -Q --batch -L "$$tmp" -L $(ACE_WINDOW) -L $(AVY) \
		-f batch-byte-compile "$$tmp"/*.el

checkdoc: check-deps
	@for file in $(CHECK_FILES); do \
		printf '== %s\n' "$$file"; \
		$(EMACS) -Q --batch $(LOAD_PATH) \
			--eval "(progn (require 'checkdoc) (checkdoc-file \"$$file\"))"; \
	done

test:
	eldev test
