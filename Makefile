.POSIX:

CRYSTAL = crystal
CRFLAGS =
OPTS = --parallel=4 --chaos -v
TESTS = test/*_test.cr

all: test

test: .phony
	$(CRYSTAL) run $(CRFLAGS) $(TESTS) -- $(OPTS)

doc: .phony
	@mkdir -p doc
	cd doc && markdown ../SPEC.md > SPEC.html

.phony:
