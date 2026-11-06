// Suíte E2E. Rodar com: E2E=1 swift test --filter E2ETests
// Toma a tela por alguns segundos — não mexa no mouse/teclado durante a execução.
//
// Todas as suítes ficam aninhadas aqui para rodarem em série (uma de cada vez).

import Testing

@Suite(.serialized, .enabled(if: e2eEnabled, "defina E2E=1 para rodar"))
struct E2E {}
