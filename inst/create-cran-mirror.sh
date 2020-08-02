#!/usr/bin/env bash

set -e

CRAN_MIRROR_HOST=${CRAN_MIRROR_HOST:-"cloud.r-project.org"}
CRAN_MIRROR_DIR=${CRAN_MIRROR_DIR:-"."}

def_mirror="$CRAN_MIRROR_HOST"
def_dest="$CRAN_MIRROR_DIR"

function show_help() {
    echo "Usage: $(basename $0) [-d PATH] [-f FILE] [-m HOST]"
    echo
    echo "where:"
    echo
    echo "  -d PATH      for CRAN mirror (defaults to $def_dest)"
    echo "  -f FILE      files to include (defults to *.tar.gz)"
    echo "  -m HOST      mirror to use (defaults to $def_mirror)"
    echo
}

dest=$def_dest
mirror=$def_mirror

while getopts "h?d:f:m:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    d)  dest=$OPTARG
        ;;
    f)  file=$OPTARG
        ;;
    m)  mirror=$OPTARG
        ;;
    esac
done

echo "Creating mirror from $mirror into $dest"

set -o xtrace

[ -d "$CRAN_MIRROR_DIR" ] || mkdir -p "$CRAN_MIRROR_DIR"
[ -d "$CRAN_MIRROR_DIR/src" ] || mkdir -p "$CRAN_MIRROR_DIR/src"

if [ ! -z "$file" ]; then
  include_opt="--include-from=$file"
else
  include_opt="--include='*.tar.gz'"
fi

rsync \
  -rtzv \
  "$include_opt" \
  --exclude='*/*' \
  "$mirror::CRAN/src/contrib" "$dest/src"

R --slave -e "tools::write_PACKAGES('$dest/src/contrib', type='source', verbose=T)"
