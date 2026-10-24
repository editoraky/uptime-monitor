#!/usr/bin/env bash
# Legt bei einer Störung genau ein Issue an und schließt es wieder, sobald
# alle Ziele antworten. Läuft nur im Workflow — braucht gh und GH_TOKEN.

set -euo pipefail

LABEL=stoerung
MELDEN_AN=${MELDEN_AN:-editoraky}
REPO=$GITHUB_REPOSITORY

offen=$(gh issue list --repo "$REPO" --label "$LABEL" --state open --limit 1 \
          --json number --jq '.[0].number // empty' 2>/dev/null || true)

case ${1:?Aufruf: incident.sh open|close} in
  open)
    # Bei anhaltender Störung bleibt es bei der einen Meldung, kein Dauerfeuer.
    if [ -n "$offen" ]; then
      echo "Störung bereits gemeldet in #$offen"
      exit 0
    fi
    gh label create "$LABEL" --repo "$REPO" --color B60205 \
       --description 'Automatisch erkannte Störung' 2>/dev/null || true
    gh issue create --repo "$REPO" \
      --title "Störung erkannt: $(date -u '+%d.%m.%Y %H:%M UTC')" \
      --label "$LABEL" \
      --assignee "$MELDEN_AN" \
      --body "@$MELDEN_AN — diese Ziele antworten nicht wie erwartet:

$BERICHT
Lauf: $GITHUB_SERVER_URL/$REPO/actions/runs/$GITHUB_RUN_ID

Dieses Issue schließt sich von selbst, sobald wieder alles antwortet."
    ;;
  close)
    if [ -z "$offen" ]; then exit 0; fi
    gh issue comment "$offen" --repo "$REPO" \
      --body "Alle Ziele antworten wieder ($(date -u '+%d.%m.%Y %H:%M UTC'))."
    gh issue close "$offen" --repo "$REPO"
    ;;
esac
