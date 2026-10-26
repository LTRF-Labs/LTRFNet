import Foundation

/// The settings in ~/.config/ltrfnet/config.json. The app reads them at start and on Renew Now.
struct Config: Codable, Equatable {
    var nameserver = ""
    var dnsDomain = ""
    var lighthouse = ""
    var hubEndpoint = ""
    var caURL = ""
    var caAppIDURI = ""

    var isComplete: Bool { ![nameserver, dnsDomain, lighthouse, hubEndpoint, caURL, caAppIDURI].contains("") }

    /// Each value without leading or trailing whitespace: a pasted space or tab breaks config.yml and the resolver.
    var trimmed: Config {
        var copy = self
        for field: WritableKeyPath<Config, String> in [\.nameserver, \.dnsDomain, \.lighthouse, \.hubEndpoint, \.caURL, \.caAppIDURI] {
            copy[keyPath: field] = copy[keyPath: field].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return copy
    }

    static let file = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/ltrfnet/config.json")

    /// The saved config, or the defaults, which it saves, when there is no file.
    static func load() throws -> Config {
        guard FileManager.default.fileExists(atPath: file.path) else { try Config().save(); return Config() }
        return try JSONDecoder().decode(Config.self, from: Data(contentsOf: file)).trimmed
    }

    func save() throws {
        try FileManager.default.createDirectory(at: Self.file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: Self.file, options: .atomic)
    }

    /// Nebula's config.yml for the files in `directory`; keys: https://github.com/slackhq/nebula/blob/v1.11.2/examples/config.yml
    func nebulaYAML(directory: URL) -> String {
        """
        pki:
          ca: \(directory.appending(path: "ca.crt").path)
          cert: \(directory.appending(path: "host.crt").path)
          key: \(directory.appending(path: "host.key").path)

        # The hub: lighthouse and relay.
        static_host_map:
          "\(lighthouse)": ["\(hubEndpoint)"]

        lighthouse:
          am_lighthouse: false
          interval: 60
          hosts:
            - "\(lighthouse)"

        # A random port: the Mac moves between networks.
        listen:
          host: 0.0.0.0
          port: 0

        punchy:
          punch: true
          respond: true

        relay:
          relays:
            - "\(lighthouse)"
          use_relays: true

        logging:
          level: info
          format: text

        # A client only: nothing on the overlay may open a connection to this Mac.
        firewall:
          outbound_action: drop
          inbound_action: drop
          outbound:
            - port: any
              proto: any
              host: any
          # Inbound: only ICMP from the developers group.
          inbound:
            - port: any
              proto: icmp
              group: developers

        """
    }
}
