# InputRemap — Plano

Substituir o Logi Options+ (~480 MB de RAM) por um app próprio e leve (~10–15 MB)
para o mouse **Logitech Lift** e o teclado **MX Keys S**, desenvolvido com
**TDD red-green** e **testes E2E em todas as funcionalidades**.

## Comportamento desejado

| Entrada | Ação |
|---|---|
| Rodinha segurada + arrastar ← | Mesa da **esquerda** (⌃←) |
| Rodinha segurada + arrastar → | Mesa da **direita** (⌃→) |
| Rodinha segurada + arrastar ↑ | Mission Control (⌃↑) |
| Rodinha segurada + arrastar ↓ | App Exposé (⌃↓) |
| Clique simples na rodinha | Mission Control (⌃↑) |
| Botão Back | ⌘C |
| Botão Forward | ⌘V |
| Tecla de print do MX Keys S (envia ⌘⇧4 nativo) | região → clipboard (atalhos do macOS trocados) |
| ⌃⇧⌘4 digitado à mão | região → arquivo (antes era ⌘⇧4) |

Decisões:
- Arrastar para a esquerda vai para a mesa da esquerda (sem inversão estilo trackpad).
- Gesto dispara **uma vez** por pressionada, no eixo dominante, ao passar do limiar.
- Framework de teste: **Swift Testing** (XCTest não está disponível só com Command Line Tools).

## Arquitetura

```
Sources/
  RemapCore/   lógica pura: evento de entrada → Decision(bloquear?, [ações])
               máquina de estados, sem dependência de macOS
  RemapIO/     adaptadores: CGEventTap (entrada) e CGEvent poster (saída)
  InputRemap/  executável: liga Core ↔ IO
Tests/
  CoreTests/   unitários do Core
  IOTests/     integração com CGEvents reais e emissor falso
  E2ETests/    binário real rodando + efeito real no macOS
```

Os atalhos gerados pelo próprio app são marcados (`eventSourceUserData`) para
não serem reprocessados (evita loop).

## Níveis de teste

| Nível | Prova | Como |
|---|---|---|
| Unitário | A lógica decide certo | `RemapCore` com eventos fictícios |
| Integração | A tradução CGEvent ↔ Core está certa | `CGEvent`s reais → callback → emissor falso |
| E2E | O app muda o macOS de verdade | Sobe o binário, injeta eventos, verifica o efeito |

Verificações E2E:

| Funcionalidade | Prova |
|---|---|
| Back → ⌘C | Janela de teste com texto selecionado → botão 3 → clipboard contém o texto |
| Forward → ⌘V | Clipboard com texto → botão 4 → texto aparece no campo |
| Arrastar ← / → | ID da mesa ativa (`CGSGetActiveSpace`) muda; requer ≥2 mesas |
| Arrastar ↑ / clique | Mission Control aberto (janelas do Dock na lista de janelas) → Esc |
| Arrastar ↓ | App Exposé aberto → Esc |
| Tecla de print | Seleção de região abre → arrasto simulado → clipboard contém imagem |
| Passagem | Clique esquerdo/direito e digitação normal passam intactos |
| Inicialização | LaunchAgent sobe o app; matar → volta; RAM < 20 MB |

**Limite:** eventos sintéticos ≠ hardware físico. Os códigos reais do Lift e da
tecla de print são cobertos por checklist manual (Fase 1 e Fase 10), via log.

## Ciclo por funcionalidade

1. 🔴 Teste E2E falhando
2. 🔴 Testes unitários falhando
3. 🟢 Implementação mínima no Core → unitários verdes
4. 🟢 Ligação no IO → E2E verde
5. 🔵 Refatoração com tudo verde
6. Commit

## Como rodar

```sh
swift test --skip E2E   # unitários + integração (rápido, sem efeito na tela)
scripts/e2e.sh          # tudo, com E2E; toma a tela por ~25 s, não mexa no mouse
scripts/e2e.sh --filter PrintKeyTests   # só um grupo
```

`scripts/e2e.sh` anota o espaço de cada tela e a posição do cursor, leva a tela
principal para uma mesa comum (a janela de teste não abre sobre app em tela cheia),
roda `E2E=1 swift test` e restaura tudo no final, mesmo se os testes falharem.

Pré-requisitos do E2E: alguma tela com ≥2 **mesas comuns** (espaços de app em tela cheia não contam); Terminal com permissão de Acessibilidade.

**Regras de segurança do E2E** (após os incidentes 1 e 2):
- Teclas comuns (⌘C, ⌘V, letras) **nunca** são postadas globalmente: só via
  `postToPid` para a janela de teste. `Inject.systemKey` só aceita setas e Esc
  (com `precondition`).
- Em modo de teste, o InputRemap também entrega ⌘C/⌘V via `postToPid` para a
  janela de teste (flag de linha de comando).
- Testes de mesa usam a **tela do cursor** e sempre restauram a mesa original.

## Fases

- [x] **Fase 0 — Fundação**
  - [x] Pacote Swift + teste vazio rodando com `swift test`
  - [x] Spike E2E: injetar eventos e detectar troca de mesa, Mission Control, clipboard
  - [x] Spike: eventos injetados passam pelo event tap do app
- [ ] **Fase 1 — Descoberta do hardware** (Options+ pausado ~2 min)
  - [ ] Log de eventos: botões do Lift, rodinha, tecla de print
  - [ ] Códigos reais viram constantes testadas
- [x] **Fase 2 — Back → ⌘C**
- [x] **Fase 3 — Forward → ⌘V**
- [x] **Fase 4 — Clique simples na rodinha → Mission Control**
- [x] **Fase 5 — Arrastar ↑ / ↓ → Mission Control / App Exposé**
- [x] **Fase 6 — Arrastar ← / → → trocar de mesa**
- [x] **Fase 7 — Tecla de print → região no clipboard** (sem código no app:
  `scripts/configure-print-key.sh` troca os atalhos do macOS; `--undo` desfaz)
- [~] **Fase 8 — Robustez** (sem loop, religar tap após timeout, regressão de passagem)
  - [x] Cliques esquerdo/direito, botões não mapeados e digitação passam intactos (E2E)
  - [x] Botões mapeados (3, 4) não vazam para a janela (E2E)
  - [x] Atalhos gerados pelo app são marcados e ignorados — sem loop (integração)
  - [ ] Religar tap após timeout: E2E escrito mas **desativado** (incidente 4).
        Pendente: investigar com logs + checagem de mutação (remover o religamento → teste vermelho)
- [x] **Fase 9 — Empacotamento** (.app, assinatura ad-hoc, LaunchAgent, E2E de inicialização/RAM)
  - `scripts/install.sh` (e `--uninstall`): `~/Applications/InputRemap.app` + LaunchAgent
    `com.viniborba.inputremap` (RunAtLoad, KeepAlive), log em `~/Library/Logs/InputRemap.log`.
  - Instalado, ignora eventos marcados pelo E2E (0x7E57) para não mandar ⌘C/⌘V ao app do usuário.
  - Sem Acessibilidade, pede uma vez e espera (sair faria o KeepAlive relançar em loop).
  - Binário só é trocado se mudou: a permissão fica presa à assinatura ad-hoc.
  - Medido: ~2,5 MB de memória (Options+ ~480 MB).
- [ ] **Fase 10 — Troca definitiva** (checklist com hardware físico, desinstalar Options+,
  **remover Acessibilidade do Terminal**)

## Rollback

A qualquer momento: religar o Options+ (`launchctl bootstrap gui/$(id -u)
/Library/LaunchAgents/com.logi.optionsplus.plist`) e parar o InputRemap.

## Diário

- 2026-11-06 — Plano criado. Rascunho inicial (não-TDD) guardado em
  `docs/rascunho-main.swift.txt` apenas como referência.
- 2026-11-06 — Fase 0: CLT 16.2 com arquivos velhos misturados mesmo após
  reinstalar. Correções (renomeados, não apagados):
  `ManifestAPI/PackageDescription.swiftmodule/*.private.swiftinterface` → `.stale-5.10`
  (causava "Undefined symbols Package.__allocating_init") e
  `usr/include/swift/module.modulemap` → `.stale-2023` ("redefinition of module
  SwiftBridging"). Também apagar o cache `…/C/clang/ModuleCache/PackageDescription-*`.
  Se a CLT for atualizada, conferir se voltaram.
- 2026-11-06 — Ambiente: 2 telas, 2 mesas por tela. Terminal ainda sem Acessibilidade.
- 2026-11-06 — Spike E2E (Fase 0):
  - ✅ Injeção de eventos funciona (Terminal com Acessibilidade).
  - ✅ Tap em outro processo vê eventos injetados e o `eventSourceUserData`
    é preservado → marcação anti-loop viável; bloquear (`return nil`) funciona.
  - ✅ Mesa ativa via `SLSGetActiveSpace`. ⚠️ Na mesa da ponta o atalho não
    faz nada → o teste precisa escolher a direção pela posição
    (`SLSCopyManagedDisplaySpaces`) e **sempre restaurar a mesa original**.
  - ✅ Mission Control/App Exposé abertos = janelas do Dock nas camadas 18/20.
    ⚠️ Distinguir MC de Exposé por contagem de janelas não é confiável →
    E2E prova "visão geral abriu"; qual atalho foi enviado fica no teste de
    integração. Reavaliar na Fase 5.
  - ❌ Clipboard via TextEdit: a ativação do TextEdit falhou e ⌘A/⌘C caíram
    no app em foco (Arc). **Regra do E2E:** nunca injetar teclado sem foco
    garantido → usar janela própria de teste (harness) e verificar que ela é
    o app em foco antes de cada injeção; abortar o teste caso contrário.
    Nada foi alterado no Arc (só seleção + cópia); clipboard limpo.
- 2026-11-06 — ⚠️ Incidente 2 (harness): a janela de teste aparecia na frente e
  dizia ser janela-chave ("key"), mas teclas postadas em `.cghidEventTap` **não
  chegavam nela** — iam para o app ativo anterior (Arc/Ajustes). Na 2ª rodada,
  ⌘C e ⌘V (`e2e-paste-1134045407`) e 3× "a" podem ter caído em outro app.
  `postToPid` entrega corretamente. `kAXFocusedApplication` retorna -25204.
  **Decisão proposta:** E2E nunca posta teclado globalmente; em modo de teste o
  InputRemap usa `postToPid(harness)` para ⌘C/⌘V. Atalhos de sistema (⌃←→↑↓)
  seguem globais. Entrega global de ⌘C/⌘V → teste de integração + checklist
  manual com hardware.
- 2026-11-06 — Fase 0 concluída: 5 autotestes do harness verdes 3× seguidas.
  Correção: ⌃←/⌃→ agem na tela do cursor (2 telas, "mesas separadas por tela").
- 2026-11-06 — Fase 1 (descoberta, Options+ pausado ~1 min, gravador listen-only):
  - Back = `otherMouse` botão **3**; Forward = botão **4**; clique da rodinha = botão **2**.
    (Cada um também gera NX_SYSDEFINED subtype 7 com bitmask de botões — ignorar.)
  - Tecla de print do MX Keys S **sem Options+ envia ⌘⇧4** nativo (keyCode 21,
    flags ⌘+⇧, modificadores e tecla em ~1 ms) → abre a captura de região **para arquivo**.
  - "Change pointer speed": sem evento padrão identificado (provável HID++ da Logitech).
- 2026-11-06 — Fase 7 (antecipada): opção A escolhida — trocar atalhos do macOS
  (id 31 ⌘⇧4 = região→clipboard; id 30 ⌃⇧⌘4 = região→arquivo). Red: ⌘⇧4 salvava
  arquivo; green após script. Achados: a janela da captura se chama "Screenshot"
  (detectar pelo PID do `com.apple.screencaptureui`); arquivo só é gravado após a
  miniatura sumir (~5 s), primeiro com nome temporário `.Screenshot…`.
- 2026-11-06 — ⚠️ Incidente 3: Esc global sem nada aberto caía no Terminal e
  **interrompia o Claude Code**. Regra: Esc global só com a sobreposição
  confirmada aberta, e o usuário deixa o foco de teclado fora do Terminal
  durante o E2E.
- 2026-11-06 — Fase 5: E2E fortalecido — o gesto precisa abrir a visão geral com o
  botão AINDA pressionado (senão o clique ao soltar também abriria e o teste passaria
  sem a funcionalidade). App Exposé ficou travado quando a janela de teste foi
  encerrada com ele aberto (o Swift libera objetos após o último uso) → a limpeza
  fecha a visão geral com o mesmo atalho (⌃↑/⌃↓, liga/desliga) ANTES de encerrar
  janela e app. **Esc removido de todo envio global** (`globalAllowed` = só setas);
  cancelar a captura usa `postToPid` para o screencaptureui.
- 2026-11-06 — Testes de mesa: escolhem uma tela com ≥2 mesas comuns e abrem a
  janela de teste lá. A "mesa" 21 do monitor externo é um app em tela cheia (type 4)
  e é ignorada.
- 2026-11-06 — Fase 6 concluída. Achados: (1) a janela de teste não fica ativa se a
  tela principal estiver num app em tela cheia — o macOS pula para uma mesa comum e
  o usuário "perde" o Terminal; (2) `.canJoinAllSpaces` tira a janela do App Exposé.
  Solução: janela com `[.moveToActiveSpace, .fullScreenAuxiliary]`, espera do status
  "key" no harness, e `scripts/e2e.sh` + `E2ESpaces` (save/prepare/restore).
  Suíte: 26 unit/integração + 14 E2E = 40 verdes, estáveis em rodadas seguidas.
- 2026-11-06 — Fase 8: janela de teste ganhou "área de cliques" (metade de baixo);
  o NSTextView engolia eventos após um clique (loop de arrasto). `Harness.center`
  agora aponta para essa área. SIGSTOP não provoca timeout do tap (macOS espera para
  sempre) → flag de teste `--test-hang-button <n>` (trava 3 s no callback).
- 2026-11-06 — ⚠️ Incidente 4: rodando o teste de religar (hang de 3 s), uma
  sobreposição do Dock (camadas 18/20, cobrindo as duas telas, com rótulo 177×30 no
  monitor — parecia App Exposé sem janelas) ficou aberta; ⌃↑, ⌃↓ e clique em área
  vazia não fecharam; sumiu sozinha depois. Com ela aberta, `E2ESpaces restore` falhou
  (⌃←/⌃→ não trocam de espaço). Teste desativado. Ideias: logar no app os eventos
  `tapDisabledBy*`; checar se o macOS entrega os eventos atrasados do botão 6/3 de
  forma inesperada; fazer `scripts/e2e.sh` checar visão geral aberta antes de restaurar.
- 2026-11-06 — **Estado para retomar:** 47 testes (1 desativado). Próximo passo:
  **Fase 10** (checklist com o hardware físico, desinstalar Options+, tirar
  Acessibilidade do Terminal). Fase 9 feita: app instalado e com Acessibilidade. Pendência: Fase 8
  religar. Ambiente: tela do Mac = Mesa 1 | Terminal tela cheia (175) | Mesa 189;
  monitor = Mesa 60 | Claude tela cheia (21). Rodar E2E sempre via `scripts/e2e.sh`.
- 2026-11-06 — Fase 9 concluída. Achado: `pause()` dos E2E não esperava nada fora da main
  thread (RunLoop sem fontes volta na hora; o Swift Testing não usa a main thread). Os
  `pause` (inclusive o de 6 s do teste do print) eram no-op e o `waitUntil` girava sem
  dormir. Corrigido com `Thread.sleep` + teste `pauseEsperaDeVerdade`. Suíte: 55 ✔, 1
  desativado (incidente 4 — talvez relacionado: as esperas não aconteciam).
