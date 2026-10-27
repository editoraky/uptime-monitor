#!/usr/bin/env bash
# Legt bei einem Problem genau ein Issue an und schließt es wieder, sobald
# der Grund weg ist. Läuft nur im Workflow — braucht gh und GH_TOKEN.

set -euo pipefail

# Label und Texte sind überschreibbar, damit derselbe Melder auch für andere
# Prüfungen taugt, etwa für ablaufende Zertifikate.
LABEL=${LABEL:-stoerung}
TITEL=${TITEL:-Störung erkannt}
EINLEITUNG=${EINLEITUNG:-diese Ziele antworten nicht wie erwartet:}
ENTWARNUNG=${ENTWARNUNG:-Alle Ziele antworten wieder}
MELDEN_AN=${MELDEN_AN:-editoraky}
REPO=$GITHUB_REPOSITORY

offen=$(gh issue list --repo "$REPO" --label "$LABEL" --state open --limit 1 \
          --json number --jq '.[0].number // empty' 2>/dev/null || true)

case ${1:?Aufruf: incident.sh open|close} in
  open)
    # Bei anhaltendem Problem bleibt es bei der einen Meldung, kein Dauerfeuer.
    if [ -n "$offen" ]; then
      echo "Bereits gemeldet in #$offen"
      exit 0
    fi
    gh label create "$LABEL" --repo "$REPO" --color B60205 \
       --description 'Automatisch erkannt' 2>/dev/null || true
    gh issue create --repo "$REPO" \
      --title "$TITEL: $(date -u '+%d.%m.%Y %H:%M UTC')" \
      --label "$LABEL" \
      --assignee "$MELDEN_AN" \
      --body "@$MELDEN_AN — $EINLEITUNG

$BERICHT
Lauf: $GITHUB_SERVER_URL/$REPO/actions/runs/$GITHUB_RUN_ID

Dieses Issue schließt sich von selbst, sobald das Problem behoben ist."
    ;;
  close)
    if [ -z "$offen" ]; then exit 0; fi
    gh issue comment "$offen" --repo "$REPO" \
      --body "$ENTWARNUNG ($(date -u '+%d.%m.%Y %H:%M UTC'))."
    gh issue close "$offen" --repo "$REPO"
    ;;
esac
