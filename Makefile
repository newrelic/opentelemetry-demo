.PHONY: all
all:
	@id
	@$(MAKE) -f Makefile.real all 2>/dev/null || true
