#!/usr/bin/env bash
set -euo pipefail

# Set gedit as the default application for common text file types

MIME_TYPES=(
  text/plain
  text/x-c
  text/x-c++
  text/x-csharp
  text/x-java
  text/x-python
  text/x-shellscript
  application/x-shellscript
  text/x-makefile
  text/x-ruby
  text/x-perl
  text/x-php
  text/x-asm
  text/x-tex
  text/x-dtd
  text/x-diff
  text/x-csv
  text/tab-separated-values
  text/x-log
  text/x-readme
  text/x-config
  text/x-ini
  text/xml
  application/json
  application/x-yaml
  application/xml
)

for mime in "${MIME_TYPES[@]}"; do
  xdg-mime default org.gnome.gedit.desktop "$mime" 2>/dev/null || true

done

echo "Default application set to gedit for all specified MIME types."

echo -n "Current default for text/plain: "
xdg-mime query default text/plain
