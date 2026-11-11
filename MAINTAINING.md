# Datenbank-Pflege (automatisch)

Die wöchentliche Aufgabe pflegt nur `Data/Categories.lua`. Sie ändert keinen anderen Code.

Ablauf:
1. Auf CurseForge die neuen und beliebtesten Addons für WoW Forever ansehen (Filter: Spielversion Forever, sortiert nach Downloads und nach "neu").
2. Für jedes Addon, das in eine vorhandene Kategorie gehört und noch nicht erkannt wird: den Ordnernamen (aus der .toc im Download oder von der GitHub-Seite) klein geschrieben als Muster eintragen, z. B. "^questie".
3. Nur eindeutige Fälle eintragen. Im Zweifel weglassen – die automatische Erkennung über Stichwörter fängt viel ab.
4. `ns.DataVersion` auf das heutige Datum setzen.
5. In `CHANGELOG.md` einen Eintrag "Datenbank-Update JJJJ-MM-TT: +N Addons" ergänzen und die Patch-Nummer in der .toc erhöhen.
6. Struktur prüfen (alle Klammern geschlossen), committen, Tag `vX.Y.Z-beta` setzen und pushen. GitHub baut und lädt das Paket automatisch auf CurseForge hoch.
