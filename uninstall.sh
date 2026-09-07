#!/usr/bin/env bash
# Entfernt das Regenradar-Widget.
set -euo pipefail
kpackagetool6 --type Plasma/Applet --remove org.kde.plasma.regenradar
echo "Entfernt. Ein Neustart der Plasma-Shell räumt verbliebene Instanzen auf:"
echo "  systemctl --user restart plasma-plasmashell.service"
