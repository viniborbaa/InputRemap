#!/bin/sh
# Instala o InputRemap como app de verdade: ~/Applications/InputRemap.app (assinatura
# ad-hoc, sem ícone no Dock) + LaunchAgent que abre no login e relança se morrer.
#
# Uso: scripts/install.sh            instala/atualiza
#      scripts/install.sh --uninstall remove tudo
#
# Atenção: as permissões (Acessibilidade e Monitoramento de Entrada) ficam presas à assinatura do binário. Se o binário
# mudar, o macOS pode pedir as permissões de novo. Por isso o binário só é substituído
# quando muda.
set -e
cd "$(dirname "$0")/.."

LABEL=com.viniborba.inputremap
APP="$HOME/Applications/InputRemap.app"
BIN="$APP/Contents/MacOS/InputRemap"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/InputRemap.log"
DOMAIN="gui/$(id -u)"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true

if [ "$1" = "--uninstall" ]; then
    rm -f "$AGENT"
    rm -rf "$APP" "$HOME/Library/Application Support/InputRemap"
    echo "InputRemap removido."
    exit 0
fi

swift build -c release --product InputRemap >/dev/null
NEW=.build/release/InputRemap

mkdir -p "$APP/Contents/MacOS" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>$LABEL</string>
    <key>CFBundleName</key><string>InputRemap</string>
    <key>CFBundleExecutable</key><string>InputRemap</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

# Compara com o binário sem assinatura guardado na instalação anterior (fora do bundle).
LAST="$HOME/Library/Application Support/InputRemap/last-build"
if ! cmp -s "$NEW" "$LAST" 2>/dev/null || [ ! -f "$BIN" ]; then
    mkdir -p "$(dirname "$LAST")"
    cp "$NEW" "$LAST"
    cp "$NEW" "$BIN"
    # A permissão antiga não vale para o binário novo (assinatura ad-hoc) e remover/adicionar
    # nos Ajustes não a substitui direito: apaga o registro para o macOS perguntar do zero.
    tccutil reset Accessibility "$LABEL" >/dev/null 2>&1 || true
    tccutil reset ListenEvent "$LABEL" >/dev/null 2>&1 || true
    echo "binário atualizado: aceite os avisos de Acessibilidade e Monitoramento de Entrada do InputRemap"
fi
codesign --force --sign - --identifier "$LABEL" "$APP" 2>/dev/null

cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key><array><string>$BIN</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>ThrottleInterval</key><integer>3</integer>
    <key>ProcessType</key><string>Interactive</string>
    <key>StandardOutPath</key><string>$LOG</string>
    <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF

launchctl bootstrap "$DOMAIN" "$AGENT"
echo "InputRemap instalado e rodando (log: $LOG)."
