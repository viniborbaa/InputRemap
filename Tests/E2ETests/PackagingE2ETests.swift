// Fase 9 — empacotamento: .app assinado + LaunchAgent (abre no login, volta se morrer, leve).
// Testa o que `scripts/install.sh` instalou de verdade (não o binário de debug).

import Foundation
import Testing

enum Installed {
    static let label = "com.viniborba.inputremap"
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let app = home.appendingPathComponent("Applications/InputRemap.app")
    static let binary = app.appendingPathComponent("Contents/MacOS/InputRemap")
    static let agent = home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    static let logFile = home.appendingPathComponent("Library/Logs/InputRemap.log")

    /// Roda um comando e devolve (código de saída, saída padrão + erro).
    @discardableResult
    static func run(_ path: String, _ args: [String]) -> (status: Int32, out: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        guard (try? p.run()) != nil else { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    /// PID do app segundo o launchd (nil se não estiver rodando).
    static var pid: pid_t? {
        let out = run("/bin/launchctl", ["print", "gui/\(getuid())/\(label)"]).out
        guard let line = out.split(separator: "\n").first(where: { $0.contains("pid = ") }) else { return nil }
        return pid_t(line.split(separator: "=").last!.trimmingCharacters(in: .whitespaces))
    }

    /// Memória do processo como o Monitor de Atividade mostra (phys_footprint), em MB.
    static func footprintMB(_ pid: pid_t) -> Double? {
        var info = rusage_info_v4()
        let r = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return r == 0 ? Double(info.ri_phys_footprint) / 1_048_576 : nil
    }

    static var log: String { (try? String(contentsOf: logFile, encoding: .utf8)) ?? "" }
}

extension E2E {
    @Suite struct PackagingE2ETests {

        @Test func appInstaladoEAssinado() throws {
            #expect(FileManager.default.isExecutableFile(atPath: Installed.binary.path))
            let v = Installed.run("/usr/bin/codesign", ["--verify", "--strict", Installed.app.path])
            #expect(v.status == 0, "\(v.out)")
            let info = try #require(NSDictionary(contentsOf: Installed.app.appendingPathComponent("Contents/Info.plist")))
            #expect(info["CFBundleIdentifier"] as? String == Installed.label)
            #expect(info["LSUIElement"] as? Bool == true, "sem ícone no Dock")
        }

        @Test func agenteAbreNoLoginEReabreSeMorrer() throws {
            let plist = try #require(NSDictionary(contentsOf: Installed.agent))
            #expect(plist["RunAtLoad"] as? Bool == true)
            #expect(plist["KeepAlive"] as? Bool == true)
            #expect((plist["ProgramArguments"] as? [String])?.first == Installed.binary.path)
            #expect(Installed.pid != nil, "launchd deveria estar rodando o app")
        }

        @Test func voltaSozinhoDepoisDeMorto() throws {
            let old = try #require(Installed.pid)
            kill(old, SIGKILL)
            try waitUntil("launchd relançar", timeout: 15) { Installed.pid.map { $0 != old } ?? false }
        }

        @Test func interceptacaoAtivaComPermissao() throws {
            // Precisa da Acessibilidade concedida ao InputRemap (passo manual, uma vez).
            try waitUntil("app ficar pronto", timeout: 10) {
                Installed.log.split(separator: "\n").last?.contains("pronto") == true
            }
        }

        @Test func usaMenosDe20MB() throws {
            let pid = try #require(Installed.pid)
            pause(1)
            let mb = try #require(Installed.footprintMB(pid))
            #expect(mb < 20, "usando \(mb) MB")
        }
    }
}
