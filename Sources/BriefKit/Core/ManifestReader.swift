//
//  ManifestReader.swift
//  BriefKit
//
//  Created by David Sherlock on 2026.
//
//  Reading a manifest for the three things anyone wants from it: how to build, what it
//  depends on, and what it produces.
//
//  DELIBERATELY SHALLOW, and it is worth saying why rather than leaving it to look like
//  laziness. `Package.swift` is a Swift program — reading it properly means compiling and
//  running it, which is seconds per repository and needs a toolchain. `Cargo.toml` is TOML,
//  which is a real grammar. What is implemented here is pattern matching over the shapes
//  these files actually take, which is right almost always and wrong quietly rather than
//  loudly. Every reader below therefore returns what it is confident about and omits the
//  rest — a missing dependency is a smaller lie than an invented one.
//

import Foundation

public enum ManifestReader {

    /// Everything derivable from the manifests found in a survey.
    public static func read(root: URL, survey: Survey,
                            ecosystems: [Detection]) -> (commands: [Command],
                                                         dependencies: [Dependency],
                                                         entryPoints: [EntryPoint]) {
        var commands: [Command] = []
        var dependencies: [Dependency] = []
        var entryPoints: [EntryPoint] = []

        for detection in ecosystems {
            guard let manifest = detection.manifest else {
                // No manifest: the commands are still knowable for some ecosystems.
                if detection.ecosystem == .python {
                    commands.append(Command(purpose: "run", line: "python3 <script>.py",
                                            source: "loose .py files, no manifest"))
                }
                continue
            }
            let url = root.appendingPathComponent(manifest)
            switch detection.ecosystem {
            case .swift:
                let read = swiftPackage(at: url, manifest: manifest)
                commands += read.commands; dependencies += read.dependencies
                entryPoints += read.entryPoints
            case .node:
                let read = nodePackage(at: url, manifest: manifest)
                commands += read.commands; dependencies += read.dependencies
                entryPoints += read.entryPoints
            case .rust:
                let read = cargo(at: url, manifest: manifest)
                commands += read.commands; dependencies += read.dependencies
            case .php:
                let read = composer(at: url, manifest: manifest)
                commands += read.commands; dependencies += read.dependencies
            case .python:
                commands.append(Command(purpose: "test", line: "pytest", source: manifest))
            case .go:
                commands.append(Command(purpose: "build", line: "go build ./...", source: manifest))
                commands.append(Command(purpose: "test", line: "go test ./...", source: manifest))
            case .ruby:
                commands.append(Command(purpose: "test", line: "bundle exec rspec", source: manifest))
            }
        }

        if survey.rootFiles.contains("Makefile") {
            commands += makefile(at: root.appendingPathComponent("Makefile"))
        }
        return (commands, dependencies, entryPoints)
    }

    // MARK: - Swift

    static func swiftPackage(at url: URL, manifest: String)
        -> (commands: [Command], dependencies: [Dependency], entryPoints: [EntryPoint]) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return ([], [], []) }

        var commands = [Command(purpose: "build", line: "swift build", source: manifest),
                        Command(purpose: "test", line: "swift test", source: manifest)]

        var entryPoints: [EntryPoint] = []
        for match in captures(in: text, pattern: #"\.executable\(\s*name:\s*"([^"]+)""#) {
            entryPoints.append(EntryPoint(name: match, kind: "executable"))
            commands.append(Command(purpose: "run", line: "swift run \(match)", source: manifest))
        }
        for match in captures(in: text, pattern: #"\.library\(\s*name:\s*"([^"]+)""#) {
            entryPoints.append(EntryPoint(name: match, kind: "library"))
        }

        // Both spellings of a dependency: a URL, or a local path.
        var dependencies = captures(in: text, pattern: #"\.package\(url:\s*"([^"]+)""#)
            .map { url -> Dependency in
                let name = url.split(separator: "/").last.map {
                    $0.replacingOccurrences(of: ".git", with: "")
                } ?? url
                return Dependency(name: name, version: nil, ecosystem: .swift)
            }
        dependencies += captures(in: text, pattern: #"\.package\(path:\s*"([^"]+)""#)
            .map { Dependency(name: ($0 as NSString).lastPathComponent,
                              version: "local path", ecosystem: .swift) }
        return (commands, dependencies, entryPoints)
    }

    // MARK: - Node

    static func nodePackage(at url: URL, manifest: String)
        -> (commands: [Command], dependencies: [Dependency], entryPoints: [EntryPoint]) {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return ([], [], []) }

        // Scripts ARE the commands here — there is no convention to fall back on, and
        // `npm test` on a package with no test script is a lie.
        let scripts = json["scripts"] as? [String: String] ?? [:]
        let commands = scripts.keys.sorted().map { key in
            Command(purpose: key, line: "npm run \(key)", source: "\(manifest) scripts")
        }

        var dependencies: [Dependency] = []
        for key in ["dependencies", "devDependencies"] {
            for (name, version) in (json[key] as? [String: String] ?? [:]) {
                dependencies.append(Dependency(name: name, version: version, ecosystem: .node))
            }
        }
        dependencies.sort { $0.name < $1.name }

        var entryPoints: [EntryPoint] = []
        if let main = json["main"] as? String {
            entryPoints.append(EntryPoint(name: json["name"] as? String ?? "main",
                                          kind: "main", path: main))
        }
        if let bin = json["bin"] as? [String: String] {
            for (name, path) in bin.sorted(by: { $0.key < $1.key }) {
                entryPoints.append(EntryPoint(name: name, kind: "binary", path: path))
            }
        } else if let bin = json["bin"] as? String {
            entryPoints.append(EntryPoint(name: json["name"] as? String ?? "bin",
                                          kind: "binary", path: bin))
        }
        return (commands, dependencies, entryPoints)
    }

    // MARK: - Rust

    static func cargo(at url: URL, manifest: String)
        -> (commands: [Command], dependencies: [Dependency]) {
        let commands = [Command(purpose: "build", line: "cargo build", source: manifest),
                        Command(purpose: "test", line: "cargo test", source: manifest),
                        Command(purpose: "run", line: "cargo run", source: manifest)]
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return (commands, []) }

        // A WORKSPACE ROOT DECLARES MEMBERS, NOT DEPENDENCIES. Reading one and reporting the
        // handful of entries it happens to carry would say "1 dependency" of a project with a
        // hundred crates in it, each with its own. Say nothing rather than something false;
        // ``Detection/isWorkspace`` is what tells a reader where to look instead.
        if text.contains("[workspace]") { return (commands, []) }

        // Only the [dependencies] table, stopping at the next section header. Taking every
        // `name = "version"` in the file would sweep in [package], [profile] and the rest.
        var dependencies: [Dependency] = []
        var inside = false
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                inside = line == "[dependencies]" || line.hasSuffix(".dependencies]")
                continue
            }
            guard inside, !line.isEmpty, !line.hasPrefix("#"),
                  let equals = line.firstIndex(of: "=") else { continue }
            let name = line[..<equals].trimmingCharacters(in: .whitespaces)
            var version = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            version = version.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            guard !name.isEmpty else { continue }
            dependencies.append(Dependency(name: name,
                                           version: version.hasPrefix("{") ? nil : version,
                                           ecosystem: .rust))
        }
        return (commands, dependencies)
    }

    // MARK: - PHP

    static func composer(at url: URL, manifest: String)
        -> (commands: [Command], dependencies: [Dependency]) {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return ([], []) }
        var commands: [Command] = []
        if let scripts = json["scripts"] as? [String: Any] {
            for key in scripts.keys.sorted() {
                commands.append(Command(purpose: key, line: "composer \(key)",
                                        source: "\(manifest) scripts"))
            }
        }
        let dependencies = (json["require"] as? [String: String] ?? [:])
            .sorted { $0.key < $1.key }
            .map { Dependency(name: $0.key, version: $0.value, ecosystem: .php) }
        return (commands, dependencies)
    }

    // MARK: - Make

    /// Target names from a Makefile.
    ///
    /// Skips `.PHONY` and pattern rules, which are not things a person runs.
    static func makefile(at url: URL) -> [Command] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var commands: [Command] = []
        for raw in text.split(separator: "\n") {
            let line = String(raw)
            guard !line.hasPrefix("\t"), !line.hasPrefix("."), !line.hasPrefix("#"),
                  let colon = line.firstIndex(of: ":") else { continue }
            let target = line[..<colon].trimmingCharacters(in: .whitespaces)
            guard !target.isEmpty, !target.contains("%"), !target.contains("="),
                  !target.contains(" "), !target.contains("$") else { continue }
            commands.append(Command(purpose: target, line: "make \(target)", source: "Makefile"))
        }
        return commands
    }

    // MARK: - Helpers

    /// First capture group of every match.
    static func captures(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: text)
            else { return nil }
            return String(text[r])
        }
    }
}
