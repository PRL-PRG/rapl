.PHONY: all build check document test

all: document build check

build: document
	R CMD build .

check: build
	R CMD check runr*tar.gz

clean:
	-rm -f runr*tar.gz
	-rm -fr runr.Rcheck

test:
	Rscript -e 'devtools::test()'

install:
	R CMD INSTALL .
