// Fase 7 — tecla de print do MX Keys S (envia ⌘⇧4) → captura de região no clipboard.

import AppKit
import Testing

extension E2E {
    @Suite struct PrintKeyTests {

        /// Captura em arquivo só é gravada depois que a miniatura no canto some (~5 s),
        /// por isso as esperas longas.
        /// Captura em arquivo só é gravada depois que a miniatura no canto some (~5 s),
        /// por isso as esperas longas.
        /// Captura em arquivo só é gravada depois que a miniatura no canto some (~5 s),
        /// por isso as esperas longas.
        @Test func cmdShift4CopiaRegiaoParaClipboard() throws {
            try #require(ScreenshotShortcut.cmdShift4IsSystemHotkey)
            let before = ScreenCapture.files()
            var newFiles: Set<String> { ScreenCapture.files().subtracting(before) }
            defer {
                if ScreenCapture.selectionIsOpen { ScreenCapture.cancelSelection() }
                // Limpa arquivos criados pelo teste (rodada vermelha), esperando a gravação tardia.
                _ = try? waitUntil("arquivo tardio", timeout: 8) { !newFiles.isEmpty }
                for f in newFiles {
                    try? FileManager.default.removeItem(at: ScreenCapture.saveDirectory.appendingPathComponent(f))
                }
            }
            Clipboard.set("antes")

            Inject.printKey()
            try waitUntil("seleção de região abrir") { ScreenCapture.selectionIsOpen }
            ScreenCapture.dragSmallRegion()

            _ = try? waitUntil("captura terminar", timeout: 8) { Clipboard.hasImage || !newFiles.isEmpty }
            #expect(Clipboard.hasImage, "clipboard deveria conter a imagem")
            pause(6) // garante que nenhum arquivo aparece depois
            #expect(newFiles.isEmpty, "não deveria salvar arquivo")
        }

        @Test func ctrlCmdShift4ContinuaSalvandoEmArquivo() {
            let b = ScreenshotShortcut.binding(ScreenshotShortcut.areaToFile)
            #expect(b?.enabled == true)
            #expect(b?.params == ScreenshotShortcut.ctrlCmdShift4)
        }

        @Test func cmdShift4EhOAtalhoDeRegiaoParaClipboard() {
            let b = ScreenshotShortcut.binding(ScreenshotShortcut.areaToClipboard)
            #expect(b?.enabled == true)
            #expect(b?.params == ScreenshotShortcut.cmdShift4)
        }
    }
}
