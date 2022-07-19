.POSIX:

PREFIX = /usr/local
LIB = $(PREFIX)/lib/tcl
BIN = $(PREFIX)/bin

.SUFFIXES: .png .png_b64

.png.png_b64:
	base64 $< | tee $@

SOURCES = pkgIndex.tcl \
	browser.tcl \
	connect.tcl \
	personality.tcl \
	queryeditor.tcl \
	sidebar.tcl \
	table.tcl \
	icon-256x256.png \
	icon-32x32.png

default:
	@echo "valid targets: install"
	@echo "influential macros:"
	@echo "PREFIX = $(PREFIX)"
	@echo "LIB = $(LIB)"
	@echo "BIN = $(BIN)"

install:
	mkdir -p $(LIB)/application-dbluejay
	mkdir -p $(BIN)
	cp -p $(SOURCES) $(LIB)/application-dbluejay/
	cp -p dbluejay $(BIN)
