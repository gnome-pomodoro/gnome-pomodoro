#!/bin/sh
# Run this to generate all the initial makefiles, etc.

srcdir=`dirname $0`
test -z "$srcdir" && srcdir=.

PKG_NAME="gnome-pomodoro"

(test -f $srcdir/configure.ac) || {
    echo -n "**Error**: Directory "\`$srcdir\'" does not look like the"
    echo " top-level $PKG_NAME directory"
    exit 1
}

which gnome-autogen.sh || {
    echo "You need to install gnome-common from GNOME git (or from"
    echo "your OS vendor's package manager)."
    exit 1
}

git submodule update --init --recursive

REQUIRED_AUTOMAKE_VERSION=1.9 . gnome-autogen.sh
