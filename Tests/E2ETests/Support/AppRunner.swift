// Sobe o binário real do InputRemap para os testes E2E.

import Foundation

final class AppRunner {
    let process = Process()
    private let pipe = Pipe()
    private var output = ""
    private let lock = NSLock()

    /// `deliverTo`: em modo de teste, ⌘C/⌘V vão direto para esse processo (postToPid),
    /// nunca para o app em foco do usuário.
    init(deliverTo pid: pid_t, hangButton: Int? = nil) throws {
        process.executableURL = builtProduct("InputRemap")
        process.arguments = ["--deliver-to-pid", String(pid)]
            + (hangButton.map { ["--test-hang-button", String($0)] } ?? [])
        process.standardOutput = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            guard let self, let s = String(data: h.availableData, encoding: .utf8) else { return }
            lock.lock(); output += s; lock.unlock()
        }
        try process.run()
        try waitUntil("InputRemap ficar pronto", timeout: 5) { self.log.contains("pronto") }
    }

    var log: String { lock.lock(); defer { lock.unlock() }; return output }

    deinit {
        pipe.fileHandleForReading.readabilityHandler = nil
        process.terminate()
        process.waitUntilExit()
    }
}
