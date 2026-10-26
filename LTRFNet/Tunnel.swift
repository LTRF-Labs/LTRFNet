import AppKit
import Observation
import ServiceManagement

/// The tunnel: the two root daemons, the files in ~/Library/Application Support/LTRFNet and the certificate renewal.
///
/// install.sh installs the daemons and Nebula's config.yml as root, after one password prompt; a change to Settings
/// needs Install… again. The daemon se.ltrf.ltrfnet.nebula runs Nebula while the file `enabled` exists. The daemon
/// se.ltrf.ltrfnet.reload sees each file that the app writes or removes there, writes /etc/resolver/<domain> from
/// `domain` and `nameserver`, and makes Nebula reload (SIGHUP) or stop (SIGTERM).
/// The 8-hour certificate is renewed with the developer's az login when 4 hours or less are left.
@MainActor @Observable
final class Tunnel {
    static let directory = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/LTRFNet")
    private static let installedConfig = "/Library/Application Support/LTRFNet/config.yml"
    private static let enabledFile = directory.appending(path: "enabled")
    private static let renewBefore: TimeInterval = 4 * 3600
    private static let nebulaCert = Bundle.main.url(forAuxiliaryExecutable: "nebula-cert")!.path

    private(set) var config: Config
    private(set) var installed = false
    private(set) var enabled = false
    private(set) var expires: Date?
    private(set) var problem: String?

    var status: String {
        if let problem { return problem }
        guard let expires else { return "No certificate" }
        guard expires > .now else { return "Certificate expired" }
        return "Certificate valid until \(expires.formatted(date: .omitted, time: .shortened))"
    }

    init() {
        do { config = try Config.load() } catch { config = Config(); problem = "config.json: \(error.localizedDescription)" }
        // Version 0.1.0 kept these files in /Users/Shared, where any local user can make the folder.
        let old = URL(filePath: "/Users/Shared/ltrfnet")
        if FileManager.default.fileExists(atPath: old.path), !FileManager.default.fileExists(atPath: Self.directory.path) {
            try? FileManager.default.moveItem(at: old, to: Self.directory)
            for stale in ["config.yml", "resolver"] { try? FileManager.default.removeItem(at: Self.directory.appending(path: stale)) }
        }
        enabled = FileManager.default.fileExists(atPath: Self.enabledFile.path)
        installed = Self.isInstalled(config)
        try? SMAppService.mainApp.register()
        Task {
            expires = try? await readExpiry()
            while true {
                if enabled {
                    await attempt {
                        try await self.writeFiles()
                        try await self.renew(force: false)
                    }
                }
                try? await Task.sleep(for: .seconds(1800))
            }
        }
    }

    func setEnabled(_ on: Bool) async {
        await attempt {
            if on {
                try await self.writeFiles()
                try await self.renew(force: false)
                try self.write("", to: "enabled")
            } else if FileManager.default.fileExists(atPath: Self.enabledFile.path) {
                try FileManager.default.removeItem(at: Self.enabledFile)
            }
        }
        enabled = FileManager.default.fileExists(atPath: Self.enabledFile.path)
    }

    /// Installs or updates the daemons and Nebula's config after one password prompt.
    func install() async {
        await attempt { try await self.writeFiles() }
        if problem == nil { runAsRoot("install", input: config.nebulaYAML(directory: Self.directory)) }
    }

    /// Stops Nebula and removes the daemons, Nebula's copy and the resolver.
    func uninstall() {
        try? FileManager.default.removeItem(at: Self.enabledFile)
        enabled = false
        runAsRoot("uninstall")
    }

    /// Runs install.sh as root with `input` on its stdin. Each value is quoted for sh, then for AppleScript.
    private func runAsRoot(_ argument: String, input: String = "") {
        let script = Bundle.main.url(forResource: "install", withExtension: "sh")!.path
        let sh = { (value: String) in "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let command = "printf %s \(sh(input)) | /bin/sh \(sh(script)) \(argument) \(sh(Self.directory.path))"
        let quoted = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var error: NSDictionary?
        NSAppleScript(source: "do shell script \"\(quoted)\" with administrator privileges")!.executeAndReturnError(&error)
        // -128: the user cancelled the password prompt.
        if let error, error[NSAppleScript.errorNumber] as? Int != -128 { problem = error[NSAppleScript.errorMessage] as? String }
        installed = Self.isInstalled(config)
    }

    /// Whether Nebula's copy, the daemons and Nebula's config are the same as this app and `config` make them.
    private static func isInstalled(_ config: Config) -> Bool {
        let resources = Bundle.main.resourceURL!
        let installedText = { (path: String) in try? String(contentsOfFile: path, encoding: .utf8) }
        return FileManager.default.contentsEqual(atPath: Bundle.main.url(forAuxiliaryExecutable: "nebula")!.path, andPath: "/Library/Application Support/LTRFNet/nebula")
            && installedText(installedConfig) == config.nebulaYAML(directory: directory)
            && ["se.ltrf.ltrfnet.nebula", "se.ltrf.ltrfnet.reload"].allSatisfy {
                let plist = try? String(contentsOf: resources.appending(path: "\($0).plist"), encoding: .utf8)
                return installedText("/Library/LaunchDaemons/\($0).plist") == plist?.replacingOccurrences(of: "__USER_DIR__", with: directory.path)
            }
    }

    /// Reads config.json again, writes Nebula's files and renews the certificate now.
    func renewNow() async {
        await attempt {
            self.config = try Config.load()
            try await self.writeFiles()
            try await self.renew(force: true)
        }
        installed = Self.isInstalled(config)
    }

    func save(_ new: Config) async {
        let new = new.trimmed
        await attempt {
            try new.save()
            self.config = new
            try await self.writeFiles()
        }
        installed = Self.isInstalled(config)
    }

    private func attempt(_ work: () async throws -> Void) async {
        do { try await work(); problem = nil } catch { problem = error.localizedDescription }
    }

    /// The folder (yours only), the key pair, and the resolver's domain and nameserver.
    private func writeFiles() async throws {
        guard config.isComplete else { throw Failure("Fill in all fields in Settings…") }
        try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let key = Self.directory.appending(path: "host.key")
        if !FileManager.default.fileExists(atPath: key.path) {
            _ = try await shell(Self.nebulaCert, "keygen", "-out-key", key.path, "-out-pub", Self.directory.appending(path: "host.pub").path)
        }
        try write(config.nameserver, to: "nameserver")
        try write(config.dnsDomain, to: "domain")
    }

    private func renew(force: Bool) async throws {
        if !force, let expires, expires.timeIntervalSinceNow > Self.renewBefore { return }
        let token: String
        do {
            token = try await shell("az", "account", "get-access-token", "--resource", config.caAppIDURI, "--query", "accessToken", "--output", "tsv")
        } catch {
            throw Failure("Run az login")
        }
        // https only: the request carries the az token.
        guard let url = URL(string: config.caURL), url.scheme == "https" else { throw Failure("CA URL must start with https://") }
        var request = URLRequest(url: url.appending(path: "sign"), timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let publicKey = try String(contentsOf: Self.directory.appending(path: "host.pub"), encoding: .utf8)
        request.httpBody = try JSONEncoder().encode(["public_key": publicKey])
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw Failure("The CA refused (\(code)): \(String(decoding: data, as: UTF8.self))") }
        struct Issued: Decodable { let ca: String; let certificate: String }
        let issued = try JSONDecoder().decode(Issued.self, from: data)
        // The CA first: the reload daemon may reload after either file.
        try write(issued.ca, to: "ca.crt")
        try write(issued.certificate, to: "host.crt")
        expires = try await readExpiry()
    }

    private func readExpiry() async throws -> Date? {
        let certificate = Self.directory.appending(path: "host.crt")
        guard FileManager.default.fileExists(atPath: certificate.path) else { return nil }
        struct Printed: Decodable { struct Details: Decodable { let notAfter: Date }; let details: Details }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = try await shell(Self.nebulaCert, "print", "-json", "-path", certificate.path)
        return try decoder.decode([Printed].self, from: Data(json.utf8)).first?.details.notAfter
    }

    /// Writes only a changed file: each write makes the reload daemon run.
    private func write(_ text: String, to name: String) throws {
        let file = Self.directory.appending(path: name), data = Data(text.utf8)
        if (try? Data(contentsOf: file)) != data { try data.write(to: file, options: .atomic) }
    }
}

struct Failure: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

/// Runs a command with Homebrew on PATH (an app from Finder gets only /usr/bin:/bin:/usr/sbin:/sbin) and returns its output.
nonisolated func shell(_ arguments: String...) async throws -> String {
    try await Task.detached {
        let process = Process()
        let output = Pipe(), errors = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"]) { $1 }
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        let out = output.fileHandleForReading.readDataToEndOfFile()
        let err = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw Failure(String(decoding: err, as: UTF8.self)) }
        return String(decoding: out, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }.value
}
