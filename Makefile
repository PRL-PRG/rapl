.PHONY: all build check document test

all: document build check

build: document
	R CMD build .

check: build
	R CMD check rapr*tar.gz

clean:
	-rm -f rapr*tar.gz
	-rm -fr rapr.Rcheck

test:
	Rscript -e 'devtools::test()'

install:
	R CMD INSTALL .
