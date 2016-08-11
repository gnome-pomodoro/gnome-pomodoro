#!/bin/sh
# Run this to generate all the initial makefiles, etc.
test -n "$srcdir" || srcdir=`dirname "$0"`
test -n "$srcdir" || srcdir=.

olddir=`pwd`
cd $srcdir

(test -f configure.ac) || {
    echo "*** ERROR: Directory "\`$srcdir\'" does not look like the top-level project directory ***"
    exit 1
}

PKG_NAME=`autoconf --trace 'AC_INIT:$1' configure.ac`

aclocal --install || exit 1
autoreconf --verbose --force --install -Wno-portability || exit 1

cd $olddir
if [ "$NOCONFIGURE" = "" ]; then
    $srcdir/configure "$@" || exit 1
    echo "Now type \`make' to compile $PKG_NAME" || exit 1
else
    echo "Skipping configure process."
fi
