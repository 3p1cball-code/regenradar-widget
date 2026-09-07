#!/usr/bin/env bash
# Installiert bzw. aktualisiert das Regenradar-Widget.
set -euo pipefail
cd "$(dirname "$0")"

ID=org.kde.plasma.regenradar

if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -q "$ID"; then
    kpackagetool6 --type Plasma/Applet --upgrade package
else
    kpackagetool6 --type Plasma/Applet --install package
fi

echo
read -r -p "Plasma-Shell jetzt neu starten, damit die Änderung greift? [J/n] " a
case "${a:-J}" in
    [Nn]*) echo "Übersprungen — Änderungen greifen nach dem nächsten Shell-Neustart." ;;
    *)     systemctl --user restart plasma-plasmashell.service && echo "Shell neu gestartet." ;;
esac

echo
echo "Hinzufügen: Rechtsklick auf den Desktop → 'Widgets hinzufügen…' → 'Regenradar'."
