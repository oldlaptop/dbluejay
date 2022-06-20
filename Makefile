.POSIX:

PREFIX = /usr/local
LIB = $(PREFIX)/lib/tcl
BIN = $(PREFIX)/bin

SOURCES = pkgIndex.tcl \
	browser.tcl \
	connect.tcl \
	personality.tcl \
	queryeditor.tcl \
	sidebar.tcl \
	table.tcl

default:
	@echo "valid targets: install"
	@echo "influential macros:"
	@echo "PREFIX = $(PREFIX)"
	@echo "LIB = $(LIB)"
	@echo "BIN = $(BIN)"

install:
	mkdir -p $(LIB)
	mkdir -p $(BIN)
	cp -p $(SOURCES) $(LIB)/
	cp -p dbluejay $(BIN)
