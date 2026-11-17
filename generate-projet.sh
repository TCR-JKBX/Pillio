#!/bin/sh
set -eu

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen est requis. Installez-le avec : brew install xcodegen" >&2
  exit 1
fi

xcodegen generate --spec project.yml
echo "Pillio.xcodeproj a été créé. Ouvrez-le dans Xcode."
