#!/bin/bash
# This command is one entrypoint that delegates to the concrete scripts to make the docker interface nicer.
# It includes no business logic on it's own, only argument parsing and delegation.
#
# Usage: cli.sh <command> [args...]
# 
# The command may be any executable *.sh file in this directory
# The rest of the args are passed untouched into the subprocess

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

COMMAND=${1:-}

if [ -z "$COMMAND" ]; then
    echo "Error: Command not specified"
    exit 1
fi

# Ensure we have the command
if [ ! -f "$SCRIPT_DIR/$COMMAND.sh" ]; then
    echo "Error: Command $COMMAND not found"
    exit 1
fi

# Ensure it is executable (not helpers.sh for example)
if [ ! -x "$SCRIPT_DIR/$COMMAND.sh" ]; then
    echo "Error: Command $COMMAND is not executable"
    exit 1
fi

shift

echo "Calling:" "$SCRIPT_DIR/$COMMAND.sh" "$@"
exec "$SCRIPT_DIR/$COMMAND.sh" "$@"


