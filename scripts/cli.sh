#!/bin/bash
# This command is one entrypoint that delegates to the concrete scripts to make the docker interface nicer.
# It includes no business logic on its own, only argument parsing and delegation.
#
# Usage: cli.sh <command> [args...]
# 
# The command may be any executable *.sh file in this directory
# The rest of the args are passed untouched into the subprocess

set -o errexit -o nounset -o pipefail
# command -v shellcheck >/dev/null && shellcheck "$0"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

usage() {
    echo "Usage: $0: [-m mode] [-s signature] <command> [args]"
    exit 2
}

# Parse out the option flags
SIG=ecdsa
MODE=eigen
while getopts s:m: opt
do
    case $opt in
    s)    SIG="$OPTARG";;
    m)    MODE="$OPTARG";;
    ?)   usage;;
    esac
done
shift $(($OPTIND - 1))

# Ensure there is at least one positional argument with the command name
if [ "$#" -eq 0 ]; then
    usage
fi
CMD="$SIG/$MODE/$1.sh"
shift

# Ensure command path exists and is executable
if [ ! -f "$SCRIPT_DIR/$CMD" ]; then
    echo "Error: Command $CMD not found"
    exit 1
fi
if [ ! -x "$SCRIPT_DIR/$CMD" ]; then
    echo "Error: Command $CMD is not executable"
    exit 1
fi

# echo "Calling:" "$SCRIPT_DIR/$CMD" "$@"
exec "$SCRIPT_DIR/$CMD" "$@"
