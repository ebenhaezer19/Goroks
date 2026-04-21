#!/bin/bash

TARGET=$1
OUTPUT=$2

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

bash "$SCRIPT_DIR/GitTools/Dumper/gitdumper.sh" "$TARGET" "$OUTPUT"
