.POSIX:

CRYSTAL = crystal
CRFLAGS =

all: test

doc: PHONY
	@mkdir -p doc
	cd doc && markdown ../SPEC.md > SPEC.html

test: PHONY
	$(CRYSTAL) run $(CRFLAGS) test/*_test.cr -- $(ARGS)

PHONY:
