import Foundation

public struct ShellResult: Equatable, Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public var ok: Bool { exitCode == 0 }
}

public enum Shell {
    @discardableResult
    public static func run(
        _ executable: String,
        _ args: [String],
        cwd: URL? = nil,
        env: [String: String]? = nil
    ) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        if let cwd { process.currentDirectoryURL = cwd }
        if let env { process.environment = env }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        final class DataBox: @unchecked Sendable { var data = Data() }
        let errBox = DataBox()
        let errHandle = errPipe.fileHandleForReading
        let sem = DispatchSemaphore(value: 0)

        try process.run()
        DispatchQueue.global().async {
            errBox.data = errHandle.readDataToEndOfFile()
            sem.signal()
        }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        sem.wait()
        let errData = errBox.data
        process.waitUntilExit()

        return ShellResult(
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self),
            exitCode: process.terminationStatus
        )
    }
}
