import Foundation

struct Exporter {
    enum ExportError: LocalizedError {
        case missingTemplate
        case invalidTemplate(String)
        case invalidVideo
        case invalidDestination
        case signingFailed(String)
        case verificationFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingTemplate:
                return "The app is missing its embedded VideoScreenSaver.saver template. Rebuild Video Screen Saver Generator."
            case .invalidTemplate(let reason):
                return "The embedded screen saver template is invalid: \(reason)"
            case .invalidVideo:
                return "The selected video does not exist or is empty."
            case .invalidDestination:
                return "The destination folder for the .saver file is unavailable."
            case .signingFailed:
                return "Signing the generated screen saver failed."
            case .verificationFailed:
                return "Verification of the generated screen saver failed."
            }
        }

        var technicalDetails: String? {
            switch self {
            case .signingFailed(let message), .verificationFailed(let message):
                return message
            case .missingTemplate, .invalidTemplate, .invalidVideo, .invalidDestination:
                return nil
            }
        }
    }

    static func safeFileName(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = name.components(separatedBy: illegal).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Video Screen Saver" : cleaned
    }

    @discardableResult
    static func export(
        videoURL: URL,
        destinationURL: URL,
        displayName: String,
        contentMode: SaverContentMode,
        muted: Bool
    ) throws -> URL {
        let fm = FileManager.default

        guard let attrs = try? fm.attributesOfItem(atPath: videoURL.path),
              let fileSize = attrs[.size] as? NSNumber,
              fileSize.int64Value > 0 else {
            throw ExportError.invalidVideo
        }

        guard let template = Bundle.main.url(forResource: "VideoScreenSaver", withExtension: "saver") else {
            throw ExportError.missingTemplate
        }
        try validateTemplate(at: template)

        var destination = destinationURL
        if destination.pathExtension.lowercased() != "saver" {
            destination.appendPathExtension("saver")
        }

        let parent = destination.deletingLastPathComponent()
        guard fm.fileExists(atPath: parent.path) else {
            throw ExportError.invalidDestination
        }

        let staging = fm.temporaryDirectory.appendingPathComponent(
            ".VideoScreenSaverGenerator-\(UUID().uuidString).saver",
            isDirectory: true
        )
        defer { try? fm.removeItem(at: staging) }

        try fm.copyItem(at: template, to: staging)

        let resources = staging
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
        try fm.createDirectory(at: resources, withIntermediateDirectories: true)

        if let items = try? fm.contentsOfDirectory(at: resources, includingPropertiesForKeys: nil) {
            for item in items where item.lastPathComponent.lowercased().hasPrefix("video.") {
                try? fm.removeItem(at: item)
            }
        }

        let ext = normalizedVideoExtension(videoURL.pathExtension)
        let embeddedVideo = resources.appendingPathComponent("video.\(ext)")
        try fm.copyItem(at: videoURL, to: embeddedVideo)

        let config: [String: Any] = [
            "ContentMode": contentMode.rawValue,
            "Muted": muted,
            "AggressiveLegacyCleanup": true
        ]
        let configData = try PropertyListSerialization.data(
            fromPropertyList: config,
            format: .xml,
            options: 0
        )
        try configData.write(
            to: resources.appendingPathComponent("SaverConfig.plist"),
            options: .atomic
        )

        let infoURL = staging.appendingPathComponent("Contents/Info.plist")
        let infoData = try Data(contentsOf: infoURL)
        guard var info = try PropertyListSerialization.propertyList(
            from: infoData,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw ExportError.invalidTemplate("Info.plist could not be read")
        }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "Video Screen Saver" : trimmedName
        info["CFBundleName"] = finalName
        info["CFBundleDisplayName"] = finalName
        info["CFBundleIdentifier"] = "local.videoscreensavergenerator.generated.\(stableIdentifier(from: finalName))"
        info["CFBundleVersion"] = String(Int(Date().timeIntervalSince1970))
        info["NSPrincipalClass"] = "VideoScreenSaverView"

        let rewrittenInfo = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try rewrittenInfo.write(to: infoURL, options: .atomic)

        try adHocSign(staging)
        try verifyGeneratedSaver(at: staging, expectedVideo: embeddedVideo.lastPathComponent)

        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: staging, to: destination)
        // A quarantined destination folder can reattach Finder metadata during
        // the move. Clean and verify the final generated bundle as well; the
        // source video remains outside this path and is never modified.
        try cleanFinalGeneratedBundle(at: destination)
        try verifyGeneratedSaver(at: destination, expectedVideo: embeddedVideo.lastPathComponent)
        // Verification itself can cause Finder to materialize inherited metadata
        // on a quarantined destination. Scrub once more after the successful
        // verification so the returned bundle is clean for the caller.
        try cleanFinalGeneratedBundle(at: destination)
        return destination
    }

    private static func normalizedVideoExtension(_ ext: String) -> String {
        let cleaned = ext.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return "mov" }
        let allowed = CharacterSet.alphanumerics
        if cleaned.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return String(cleaned.prefix(12))
        }
        return "mov"
    }

    private static func stableIdentifier(from input: String) -> String {
        let ascii = input.lowercased().unicodeScalars.map { scalar -> Character in
            switch scalar.value {
            case 48...57, 97...122:
                return Character(String(scalar))
            default:
                return "-"
            }
        }
        let compact = String(ascii)
            .split(separator: "-")
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let prefix = String(compact.prefix(36))

        var hash: UInt64 = 0xcbf29ce484222325
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        let hashString = String(hash, radix: 16, uppercase: false)
        return prefix.isEmpty ? "video-\(hashString)" : "\(prefix)-\(hashString)"
    }

    private static func validateTemplate(at url: URL) throws {
        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        let executableURL = url.appendingPathComponent("Contents/MacOS/VideoScreenSaver")

        guard FileManager.default.fileExists(atPath: infoURL.path),
              FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw ExportError.invalidTemplate("Missing Info.plist or VideoScreenSaver executable")
        }

        let data = try Data(contentsOf: infoURL)
        guard let info = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any],
              info["NSPrincipalClass"] as? String == "VideoScreenSaverView" else {
            throw ExportError.invalidTemplate("NSPrincipalClass is not VideoScreenSaverView")
        }
    }

    private static func verifyGeneratedSaver(at url: URL, expectedVideo: String) throws {
        let resources = url.appendingPathComponent("Contents/Resources", isDirectory: true)
        let video = resources.appendingPathComponent(expectedVideo)
        guard FileManager.default.fileExists(atPath: video.path) else {
            throw ExportError.verificationFailed("The embedded video is missing from Resources")
        }

        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: infoURL)
        guard let info = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any],
              info["NSPrincipalClass"] as? String == "VideoScreenSaverView",
              let identifier = info["CFBundleIdentifier"] as? String,
              identifier.hasPrefix("local.videoscreensavergenerator.generated.") else {
            throw ExportError.verificationFailed("Info.plist key fields are incorrect")
        }

        let result = runProcess(
            executable: "/usr/bin/codesign",
            arguments: ["--verify", "--strict", "--verbose=2", url.path]
        )
        if result.status != 0 {
            throw ExportError.verificationFailed(
                diagnosticMessage(prefix: "codesign verification returned a non-zero status", result: result)
            )
        }
    }

    private static func cleanFinalGeneratedBundle(at bundleURL: URL) throws {
        let xattrResult = runProcess(
            executable: "/usr/bin/xattr",
            arguments: ["-c", "-r", bundleURL.path]
        )
        guard xattrResult.status == 0 else {
            throw ExportError.verificationFailed(
                diagnosticMessage(prefix: "Unable to clean the final generated bundle metadata", result: xattrResult)
            )
        }

        let fileManager = FileManager.default
        if let enumerator = fileManager.enumerator(
            at: bundleURL,
            includingPropertiesForKeys: nil,
            options: []
        ) {
            for case let item as URL in enumerator {
                if item.lastPathComponent.hasPrefix("._") {
                    try? fileManager.removeItem(at: item)
                    continue
                }
                _ = runProcess(executable: "/usr/bin/xattr", arguments: ["-d", "com.apple.FinderInfo", item.path])
                _ = runProcess(
                    executable: "/usr/bin/xattr",
                    arguments: ["-d", "com.apple.fileprovider.fpfs#P", item.path]
                )
            }
        }
        _ = runProcess(executable: "/usr/bin/dot_clean", arguments: ["-m", bundleURL.path])

        let remainingMetadata = runProcess(
            executable: "/usr/bin/xattr",
            arguments: ["-r", bundleURL.path]
        )
        if remainingMetadata.stdout.contains("com.apple.FinderInfo") ||
            remainingMetadata.stdout.contains("com.apple.fileprovider.fpfs#P") {
            throw ExportError.verificationFailed(
                diagnosticMessage(prefix: "The final generated bundle still contains Finder metadata", result: remainingMetadata)
            )
        }
    }

    private static func adHocSign(_ bundleURL: URL) throws {
        // Files selected by the user can carry FinderInfo/resource-fork/quarantine
        // xattrs. codesign rejects such metadata inside a bundle, even though the
        // video bytes themselves are perfectly valid. Strip only xattrs from the
        // generated staging bundle before signing; this does not modify the source
        // video chosen by the user.
        let xattrResult = runProcess(
            executable: "/usr/bin/xattr",
            arguments: ["-c", "-r", bundleURL.path]
        )
        guard xattrResult.status == 0 else {
            throw ExportError.signingFailed(
                diagnosticMessage(prefix: "Unable to clear generated-bundle extended attributes", result: xattrResult)
            )
        }

        // Finder can materialize AppleDouble files and FinderInfo on a newly
        // copied bundle when the destination folder is quarantined. The sibling
        // release pipeline removes the same metadata before signing. Keep this
        // cleanup scoped to the generated staging bundle only.
        let fileManager = FileManager.default
        if let enumerator = fileManager.enumerator(
            at: bundleURL,
            includingPropertiesForKeys: nil,
            options: []
        ) {
            for case let item as URL in enumerator where item.lastPathComponent.hasPrefix("._") {
                try? fileManager.removeItem(at: item)
            }
        }
        _ = runProcess(executable: "/usr/bin/dot_clean", arguments: ["-m", bundleURL.path])
        if let enumerator = fileManager.enumerator(
            at: bundleURL,
            includingPropertiesForKeys: nil,
            options: []
        ) {
            for case let item as URL in enumerator {
                _ = runProcess(
                    executable: "/usr/bin/xattr",
                    arguments: ["-d", "com.apple.FinderInfo", item.path]
                )
                _ = runProcess(
                    executable: "/usr/bin/xattr",
                    arguments: ["-d", "com.apple.fileprovider.fpfs#P", item.path]
                )
            }
        }

        let remainingMetadata = runProcess(
            executable: "/usr/bin/xattr",
            arguments: ["-r", bundleURL.path]
        )
        if remainingMetadata.stdout.contains("com.apple.FinderInfo") ||
            remainingMetadata.stdout.contains("com.apple.fileprovider.fpfs#P") {
            throw ExportError.signingFailed(
                diagnosticMessage(prefix: "Generated bundle still contains Finder metadata", result: remainingMetadata)
            )
        }

        // The template is already signed inside the app. Remove that stale
        // signature first so the rewritten Info.plist/Resources can be sealed from
        // a clean state. Failure here is non-fatal because --force below can also
        // replace a valid existing signature.
        _ = runProcess(
            executable: "/usr/bin/codesign",
            arguments: ["--remove-signature", bundleURL.path]
        )

        let signResult = runProcess(
            executable: "/usr/bin/codesign",
            arguments: ["--force", "--sign", "-", "--timestamp=none", bundleURL.path]
        )
        guard signResult.status == 0 else {
            throw ExportError.signingFailed(
                diagnosticMessage(prefix: "codesign returned a non-zero status", result: signResult)
            )
        }
    }

    private static func diagnosticMessage(prefix: String, result: ProcessResult) -> String {
        var parts = ["\(prefix)（exit \(result.status)）"]
        if !result.stdout.isEmpty { parts.append("stdout: \(result.stdout)") }
        if !result.stderr.isEmpty { parts.append("stderr: \(result.stderr)") }
        return parts.joined(separator: "\n")
    }

    private struct ProcessResult {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    private static func runProcess(executable: String, arguments: [String]) -> ProcessResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ProcessResult(status: -1, stdout: "", stderr: error.localizedDescription)
        }

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let outText = String(data: outData, encoding: .utf8) ?? ""
        let errText = String(data: errData, encoding: .utf8) ?? ""
        return ProcessResult(
            status: process.terminationStatus,
            stdout: outText.trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: errText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
