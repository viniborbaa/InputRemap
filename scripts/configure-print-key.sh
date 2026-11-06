#!/bin/sh
# Fase 7 — tecla de print do MX Keys S.
# Sem o Logi Options+, a tecla envia ⌘⇧4. Troca os atalhos de captura do macOS:
#   ⌘⇧4   → copiar região para o clipboard   (id 31)
#   ⌃⇧⌘4  → salvar região em arquivo         (id 30)
# Idempotente. Para desfazer: scripts/configure-print-key.sh --undo
set -e

CMD_SHIFT=1179648        # 0x120000
CTRL_CMD_SHIFT=1441792   # 0x160000

if [ "$1" = "--undo" ]; then FILE=$CMD_SHIFT; CLIP=$CTRL_CMD_SHIFT
else FILE=$CTRL_CMD_SHIFT; CLIP=$CMD_SHIFT; fi

entry() { echo "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>52</integer><integer>21</integer><integer>$1</integer></array><key>type</key><string>standard</string></dict></dict>"; }

defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 30 "$(entry $FILE)"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 31 "$(entry $CLIP)"

# Aplica sem precisar sair da sessão.
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
echo "atalhos de captura atualizados ($([ "$1" = "--undo" ] && echo padrão || echo 'print → clipboard'))"
