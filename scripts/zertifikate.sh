#!/usr/bin/env bash
# Warnt, bevor ein Zertifikat abläuft.
#
# Der Erreichbarkeitswächter merkt einen Ablauf erst, wenn die Seite deshalb
# schon nicht mehr erreichbar ist. Diese Prüfung meldet sich, solange noch
# Zeit zum Eingreifen bleibt.

set -uo pipefail

# Let's Encrypt erneuert ab 30 Tagen Restlaufzeit, certbot versucht es zweimal
# täglich. Wer unter diese Schwelle rutscht, scheitert seit gut einer Woche.
SCHWELLE=${SCHWELLE:-21}
ZEITLIMIT=${ZEITLIMIT:-20}

# Hostnamen aus der Zielliste ableiten, statt eine zweite Liste zu pflegen,
# die mit der ersten auseinanderlaufen kann.
hosts() {
  sed 's/\r$//' "${ZIELE:-$(dirname "$0")/../targets.txt}" |
    grep -v -E '^[[:space:]]*(#|$)' |
    cut -d'|' -f2 |
    sed -E 's#^https?://##; s#[:/].*$##' |
    sort -u
}

# Ablaufdatum des vorgelegten Zertifikats als Sekunden seit 1970.
ablauf() {
  local host=$1 ende
  ende=$(echo | timeout "$ZEITLIMIT" openssl s_client -connect "$host:443" \
           -servername "$host" 2>/dev/null |
         openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  [ -n "$ende" ] || return 1
  date -u -d "$ende" '+%s'
}

bericht=''
warnungen=0
jetzt=$(date -u '+%s')

for host in $(hosts); do
  if ! ende=$(ablauf "$host"); then
    printf 'FEHL  %s - Zertifikat nicht lesbar\n' "$host"
    bericht+="- **$host**: Zertifikat nicht lesbar"$'\n'
    warnungen=$((warnungen + 1))
    continue
  fi

  tage=$(( (ende - jetzt) / 86400 ))

  # Ein negativer Wert heißt: bereits abgelaufen. Dieselbe Schwelle fängt das mit.
  if [ "$tage" -le "$SCHWELLE" ]; then
    printf 'WARN  %s - noch %s Tag(e)\n' "$host" "$tage"
    bericht+="- **$host**: noch $tage Tag(e) gültig"$'\n'
    warnungen=$((warnungen + 1))
  else
    printf 'OK    %s - noch %s Tage\n' "$host" "$tage"
  fi
done

printf '\n%s Zertifikat(e) brauchen Aufmerksamkeit\n' "$warnungen"

{
  printf 'warnungen=%s\n' "$warnungen"
  printf 'bericht<<ENDE_BERICHT\n%sENDE_BERICHT\n' "$bericht"
} >> "${GITHUB_OUTPUT:-/dev/null}"
