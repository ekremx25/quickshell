#!/usr/bin/env bash
set -euo pipefail
command -v python3 >/dev/null || { echo 'Python 3.10+ is required.' >&2; exit 1; }
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else "Python 3.10+ is required.")'
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$source_dir/scripts/install_quickshell.py" ]]; then
    exec python3 -B "$source_dir/scripts/install_quickshell.py" "$@"
fi
# A downloaded/process-substitution entrypoint needs the rest of the repository.
command -v git >/dev/null || { echo 'Git is required to download the configuration.' >&2; exit 1; }
checkout="$(mktemp -d "${TMPDIR:-/tmp}/quickshell-install.XXXXXXXX")"
trap 'rm -rf -- "$checkout"' EXIT
ref="${QUICKSHELL_INSTALL_REF:-main}"
# Public HTTPS only. Ignore user credential helpers and URL-to-SSH rewrites
# for this download, without changing the user's Git configuration.
if ! (
    cd -- "$checkout"
    unset GIT_CONFIG_PARAMETERS GIT_CONFIG GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR
    export GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/false SSH_ASKPASS=/bin/false
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_COUNT=0
    git -c credential.helper= -c credential.interactive=false -c core.askPass=/bin/false \
        clone --quiet --depth 1 --branch "$ref" -- https://github.com/ekremx25/quickshell.git "$checkout/source"
); then
    echo 'Public download failed without requesting GitHub credentials. Check connectivity and the public repository/ref; no login is required.' >&2
    exit 1
fi
python3 -B "$checkout/source/scripts/install_quickshell.py" "$@"
