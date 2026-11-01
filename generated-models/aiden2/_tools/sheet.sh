#!/bin/bash
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --python-use-system-env --python "$(dirname "$0")/sheet.py" -- "$@" 2>&1 | grep -E "SHEET|Error|line [0-9]" -A2
