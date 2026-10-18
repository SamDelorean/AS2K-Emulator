#!/bin/sh
set -eu
exec python3 /usr/local/libexec/as2k/frontend/as2k_session.py "$@"
