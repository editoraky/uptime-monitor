#!/usr/bin/env bash
# Prüft jedes Ziel aus targets.txt und meldet das Ergebnis an den Workflow.
#
# Ein Ziel gilt erst nach mehreren Fehlversuchen als ausgefallen, damit ein
# einzelner Aussetzer keinen Alarm auslöst.

set -uo pipefail

ZEITLIMIT=${ZEITLIMIT:-20}
VERSUCHE=${VERSUCHE:-3}
PAUSE=${PAUSE:-15}

grund=''

# Erfolg heißt: HTTP 200 und der erwartete Text steht in der Antwort.
abruf() {
  local url=$1 erwartet=$2
  local antwort code koerper

  if ! antwort=$(curl -sS --max-time "$ZEITLIMIT" -w $'\n%{http_code}' "$url" 2>&1); then
    grund="keine Verbindung: $(printf "%s" "$antwort" | tr "\n" " " | sed "s/^ *000//" | cut -c1-140)"
    return 1
  fi

  code=${antwort##*$'\n'}
  koerper=${antwort%$'\n'*}

  if [ "$code" != 200 ]; then
    grund="HTTP $code statt 200"
    return 1
  fi

  case $koerper in
    *"$erwartet"*) return 0 ;;
  esac

  grund="Antwort ohne den erwarteten Text: $erwartet"
  return 1
}

bericht=''
ausfaelle=0

while IFS='|' read -r name url erwartet; do
  case $name in ''|\#*) continue ;; esac

  erfolg=0
  for versuch in $(seq 1 "$VERSUCHE"); do
    if abruf "$url" "$erwartet"; then
      erfolg=1
      break
    fi
    if [ "$versuch" -lt "$VERSUCHE" ]; then sleep "$PAUSE"; fi
  done

  if [ "$erfolg" = 1 ]; then
    printf 'OK    %s\n' "$name"
  else
    printf 'FEHL  %s - %s\n' "$name" "$grund"
    bericht+="- **$name** ($url): $grund"$'\n'
    ausfaelle=$((ausfaelle + 1))
  fi
done < <(sed "s/\r$//" "${ZIELE:-$(dirname "$0")/../targets.txt}")

printf '\n%s Ziel(e) ohne Antwort\n' "$ausfaelle"

{
  printf 'ausfaelle=%s\n' "$ausfaelle"
  printf 'bericht<<ENDE_BERICHT\n%sENDE_BERICHT\n' "$bericht"
} >> "${GITHUB_OUTPUT:-/dev/null}"
