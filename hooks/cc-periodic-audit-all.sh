#!/usr/bin/env bash
# cc-periodic-audit-all: discover & run every *_audit.py + *_consistency.py under ~/Dev
# Output: /tmp/cc-periodic-audit-all-$(date +%F).log
# Goal: rule #24 enforcement — no audit tool is forgotten over time.
set -u
LOG=/tmp/cc-periodic-audit-all-$(date +%F).log
{
  echo "# cc-periodic-audit-all $(date -Iseconds)"
  echo "## Discovery"
  mapfile -t AUDITS < <(find /Users/tianli/Dev -type f \( -name '*_audit.py' -o -name '*_consistency.py' \) \
    -not -path '*/.venv/*' -not -path '*/_archive/*' -not -path '*/node_modules/*' 2>/dev/null | sort)
  echo "found ${#AUDITS[@]} audit tools"
  for a in "${AUDITS[@]}"; do echo "  - $a"; done
  echo
  echo "## Smoke (--help or import-only)"
  for a in "${AUDITS[@]}"; do
    rel="${a#/Users/tianli/}"
    if timeout 10 python3 "$a" --help >/dev/null 2>&1; then
      echo "  PASS --help: $rel"
    elif timeout 10 python3 -c "import importlib.util,sys; s=importlib.util.spec_from_file_location('m','$a'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m)" >/dev/null 2>&1; then
      echo "  PASS import: $rel"
    else
      echo "  WARN  cannot smoke: $rel"
    fi
  done
} > "$LOG" 2>&1
echo "audit-all log: $LOG" >&2
