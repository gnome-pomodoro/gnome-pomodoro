#!/bin/sh
# Run this to generate all the initial makefiles, etc.

PKG_NAME=gnome-pomodoro

srcdir=`dirname $0`
test -z "$srcdir" && srcdir=.

(test -f $srcdir/configure.ac) || {
    echo -n "**Error**: Directory \"\'$srcdir\'\" does not look like the"
    echo " top-level package directory"
    exit 1
}

which gnome-autogen.sh || {
    echo "You need to install gnome-common!"
    exit 1
}

REQUIRED_AUTOMAKE_VERSION=1.9 GNOME_DATADIR="$gnome_datadir" . gnome-autogen.sh
