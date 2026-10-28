#!/usr/bin/env bash
# Local Firebase emulators (Auth 9197, Firestore 8187, Functions 5107) for testing the
# web app on http://localhost:5180. Needs Java 21+ (firebase-tools requirement).
set -euo pipefail
cd "$(dirname "$0")/.."
export JAVA_HOME="${JAVA_HOME:-$HOME/tools/jdk-21}"
export PATH="$JAVA_HOME/bin:$PATH"
exec firebase emulators:start --only auth,firestore,functions --project clinic-schedule-homilabs
