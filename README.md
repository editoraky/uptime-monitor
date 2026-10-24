# Wächter

Prüft alle zehn Minuten, ob die Seiten und Mail-Dienste antworten. Läuft bei
GitHub, nicht auf dem eigenen Server — ein Wächter auf der überwachten Maschine
kann deren Ausfall nicht melden.

Bei einer Störung entsteht **ein** Issue mit Zuweisung und Erwähnung, also eine
Mail und eine Push-Nachricht. Solange die Störung anhält, bleibt es bei dieser
einen Meldung. Sobald wieder alles antwortet, kommentiert und schließt der
Ablauf das Issue von selbst.

## Ein Ziel hinzufügen

Eine Zeile in `targets.txt`:

    Name|URL|Text, der in der Antwort stehen muss

Der erwartete Text ist wichtig: Eine Angular-Seite beantwortet **jeden** Pfad
mit HTTP 200, auch wenn dahinter nichts mehr funktioniert. Erst der Textabgleich
macht aus der Erreichbarkeitsprüfung eine echte Aussage.

## Örtlich ausprobieren

    ZIELE=meine-ziele.txt VERSUCHE=2 PAUSE=1 bash scripts/check.sh

## Was nicht überwacht wird

`staging.impluence.com` lauscht nur auf der WireGuard-Adresse und ist von außen
nicht erreichbar. Dafür braucht es einen Wächter innerhalb des Netzes.
