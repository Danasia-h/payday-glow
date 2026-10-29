#!/bin/zsh
set -eu
cd "$(dirname "$0")"
mkdir -p build/module-cache
swiftc -O -module-cache-path build/module-cache Sources/WageEngine.swift Tests/main.swift -o build/EngineTests
build/EngineTests
