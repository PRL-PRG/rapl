#!/usr/bin/env bash

set -e

CRAN_MIRROR_URL=${CRAN_MIRROR_URL:-"https://cloud.r-project.org"}
R_LIBS=${R_LIBS:-"library"}

def_dest=""
def_libs="$R_LIBS"
def_mirror="$CRAN_MIRROR_HOST"
def_package_file=""

function show_help() {
    echo "Usage: $(basename $0) [-d PATH] [-f FILE] [-l PATH] [-m HOST]"
    echo
    echo "where:"
    echo
    echo "  -d PATH      where to keep downloaded sources (optional)"
    echo "  -f FILE      list of packages (defaults to all avalable packages)"
    echo "  -l PATH      where to install the packages (defaults to $def_lib)"
    echo "  -m HOST      mirror to use (defaults to $def_mirror)"
    echo
}

dest=$def_dest
mirror=$def_mirror
libs=$def_libs
package_file=$def_package_file

while getopts "h?d:f:l:m:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    d)  dest=$OPTARG
        ;;
    f)  package_file=$OPTARG
        ;;
    l)  libs=$OPTARG
        ;;
    m)  mirror=$OPTARG
        ;;
    esac
done

echo "Installing packages from $mirror into $libs (sources in $dest)"

set -o xtrace

if [ ! -z "$dest" ]; then
  [ -d "$dest" ] || mkdir -p "$dest"
  dest_opt="'$dest'"
else
  dest_opt=NULL
fi

[ -d "$libs" ] || mkdir -p "$libs"

if [ ! -z "$package_file" ]; then
  package_opt="readLines('$package_file')"
else
  package_opt="available.packages()[,1]"
fi

cat << EOF | R --slave
options(repos='$mirror')

requested <- $package_opt
installed <- installed.packages(lib.loc='$libs')[,1]
missing <- setdiff(requested, installed)

message("Installing ", length(missing), " packages from $mirror into $libs")

install.packages(
  missing,
  lib='$libs',
  destdir=$dest_opt,
  dependencies=TRUE,
  INSTALL_opts=c("--example", "--install-tests", "--with-keep.source", "--no-multiarch"),
  Ncpus=parallel::detectCores()
)
EOF

