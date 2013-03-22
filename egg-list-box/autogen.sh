#!/bin/sh
mkdir -p m4
autoreconf -fiv -Wall || exit

run_configure=true
for arg in $*; do
    case $arg in
        --no-configure)
            run_configure=false
            ;;
        *)
            ;;
    esac
done

if test $run_configure = true; then
    ./configure --enable-maintainer-mode "$@"
fi
