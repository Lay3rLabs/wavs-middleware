SUDO := if `groups | grep -q docker > /dev/null 2>&1 && echo true || echo false` == "true" { "" } else { "sudo" }

help:
  just --list

# builds middleware
docker-build TAG="local":
    {{SUDO}} docker build . -t ghcr.io/lay3rlabs/wavs-middleware:{{TAG}}
