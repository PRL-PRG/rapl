.PHONY: all build check document test

all: install

build: document
	R CMD build .

check: build
	R CMD check runr*tar.gz

clean:
	-rm -f runr*tar.gz
	-rm -fr runr.Rcheck

test:
	Rscript -e 'devtools::test()'

document:
	Rscript -e 'devtools::document()'

install:
	R CMD INSTALL .
