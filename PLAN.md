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
| Tecla de print do MX Keys S | ⌃⇧⌘4 (região → clipboard) |

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
E2E=1 swift test        # tudo; o E2E toma a tela por ~30–60 s, não mexa no mouse
```

Pré-requisitos do E2E: ≥2 mesas (Spaces); Terminal com permissão de Acessibilidade.

## Fases

- [ ] **Fase 0 — Fundação**
  - [ ] Pacote Swift + teste vazio rodando com `swift test`
  - [ ] Spike E2E: injetar eventos e detectar troca de mesa, Mission Control, clipboard
  - [ ] Spike: eventos injetados passam pelo event tap do app
- [ ] **Fase 1 — Descoberta do hardware** (Options+ pausado ~2 min)
  - [ ] Log de eventos: botões do Lift, rodinha, tecla de print
  - [ ] Códigos reais viram constantes testadas
- [ ] **Fase 2 — Back → ⌘C**
- [ ] **Fase 3 — Forward → ⌘V**
- [ ] **Fase 4 — Clique simples na rodinha → Mission Control**
- [ ] **Fase 5 — Arrastar ↑ / ↓ → Mission Control / App Exposé**
- [ ] **Fase 6 — Arrastar ← / → → trocar de mesa**
- [ ] **Fase 7 — Tecla de print → região no clipboard**
- [ ] **Fase 8 — Robustez** (sem loop, religar tap após timeout, regressão de passagem)
- [ ] **Fase 9 — Empacotamento** (.app, assinatura ad-hoc, LaunchAgent, E2E de inicialização/RAM)
- [ ] **Fase 10 — Troca definitiva** (checklist com hardware físico, desinstalar Options+)

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
