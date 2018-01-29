.POSIX:

CRYSTAL = crystal
CRFLAGS =

all: test

docs: PHONY
	$(CRYSTAL) docs

test: PHONY
	$(CRYSTAL) run $(CRFLAGS) test/*_test.cr -- $(ARGS)

PHONY:
