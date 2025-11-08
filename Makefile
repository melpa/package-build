-include config.mk
include default.mk

.PHONY: test

# https://github.com/emacscollective/workflows/blob/main/bin/install-deps
# expects this to find this in this file.
DEPS  = compat

all: lisp

help:
	$(info make all          - generate byte-code and autoloads)
	$(info make lisp         - generate byte-code and autoloads)
	$(info make redo         - re-generate byte-code and autoloads)
	$(info make test         - run tests)
	$(info make demo         - run tests showing their documentation)
	$(info make clean        - remove generated files)
	@printf "\n"

redo: clean $(ELCS) loaddefs check-declare
	@$(MAKE) -C test lisp

lisp: $(ELCS) loaddefs check-declare
	@$(MAKE) -C test lisp

loaddefs: $(PKG)-autoloads.el

%.elc: %.el
	@printf "Compiling $<\n"
	@$(EMACS) -Q --batch $(EMACS_ARGS) $(LOAD_PATH) -f batch-byte-compile $<

check-declare:
	@printf " Checking function declarations\n"
	@$(EMACS) -Q --batch $(EMACS_ARGS) $(LOAD_PATH) \
	--eval "(check-declare-directory default-directory)"

test:
	@$(MAKE) -C test test

demo:
	@$(MAKE) -C test demo

CLEAN = $(ELCS) $(PKG)-autoloads.el test/$(PKG)-tests.elc

clean:
	@printf " Cleaning...\n"
	@rm -rf $(CLEAN)

$(PKG)-autoloads.el: $(ELS)
	@printf " Creating $@\n"
	@$(EMACS) -Q --batch -l autoload --eval "\
(let* ((file (expand-file-name \"$@\"))\
       (generated-autoload-file file)\
       (coding-system-for-write 'utf-8-emacs-unix)\
       (backup-inhibited t)\
       (version-control 'never)\
       (inhibit-message t))\
  (write-region (autoload-rubric file \"package\" t) nil file)\
  (update-directory-autoloads default-directory))" \
	2>&1 | sed "/^Package autoload is deprecated$$/d"
