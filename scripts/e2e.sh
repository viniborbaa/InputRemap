#!/bin/sh
# Roda a suíte E2E guardando e restaurando o espaço de cada tela.
# Uso: scripts/e2e.sh [argumentos extras do swift test, ex.: --filter PrintKeyTests]
#
# Durante a execução (~30 s): não mexa no mouse/teclado.
cd "$(dirname "$0")/.." || exit 1
swift build --build-tests >/dev/null || exit 1
STATE=$(mktemp -t e2e-spaces)
.build/debug/E2ESpaces save "$STATE"
.build/debug/E2ESpaces prepare
E2E=1 swift test --skip-build "$@"
RESULT=$?
.build/debug/E2ESpaces restore "$STATE"
rm -f "$STATE"
exit $RESULT
