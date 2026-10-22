import CryptoKit
import Foundation

struct ShaderTechnique: Identifiable, Equatable {
    let id: String
    let name: String
    let shaderFile: String
    let enabledByDefault: Bool
    var isEnabled: Bool
}

struct ReShadeBuild: Identifiable, Hashable {
    let version: String
    let setupURL: URL
    let setupSHA256: String
    let runtimeSHA256: String
    let patchedSHA256: String
    let iidOffset: Int
    let resizeSite: Int

    var id: String { version }
}

enum InstallerError: LocalizedError {
    case invalidExecutable(String)
    case unsupportedArchitecture
    case existingInstallation
    case missingTool(String)
    case downloadFailure(String)
    case invalidDownload(String)
    case patchMismatch(String)
    case unsafeManifest
    case missingBackup(String)
    case processFailure(String)
    case filesystemFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidExecutable(let message), .downloadFailure(let message), .invalidDownload(let message), .patchMismatch(let message), .processFailure(let message), .filesystemFailure(let message): message
        case .unsupportedArchitecture: "This patch supports 64-bit Windows game executables only. Choose the game's x64 .exe."
        case .existingInstallation: "A ReShade installation is already present in this game folder. Use Restore backup before installing over it."
        case .missingTool(let tool): "Required macOS tool not found: \(tool)."
        case .unsafeManifest: "The install manifest or backup path is invalid. Nothing was changed."
        case .missingBackup(let path): "The saved backup is missing at \(path). Nothing was removed."
        }
    }
}

enum InstallerService {
    static let defaultVersion = "6.8.0"
    static let supportedBuilds = [
        ReShadeBuild(
            version: "6.8.0",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_6.8.0.exe")!,
            setupSHA256: "207aea16205fbf952bc8fe1879966672454cf04002e7ad34237c7990a5b3c0b4",
            runtimeSHA256: "b2945c29e7095491a901746b400e58db9b1592ab092bacf2a888ce37f02d08da",
            patchedSHA256: "8452bd0220d36b175babfce52d2395ef21dc47d59f116d718c287292ace2fc2a",
            iidOffset: 0x3E8208,
            resizeSite: 0x14BC40
        ),
        ReShadeBuild(
            version: "6.7.2",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_6.7.2.exe")!,
            setupSHA256: "92ad42fb05187fc03e40c4b86eb87410b0068f1ee6bef19d2db52294b529cde0",
            runtimeSHA256: "789a47742f9a9bdf14202a1d00ac98d2fef8f1240adb5e1f9ffa651b0df728a7",
            patchedSHA256: "2278882e3acef4a0718bc97ce318c3b639b6f1c7ce3e4e01c2c02f5226f8b920",
            iidOffset: 0x3D2058,
            resizeSite: 0x14BAB0
        ),
        ReShadeBuild(
            version: "5.9.2",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_5.9.2.exe")!,
            setupSHA256: "ec5e9d128d4460e212ca859cb257c95bba3776d412fe7859c4c8c91633e3c9dd",
            runtimeSHA256: "d39d04d1931ede6ed4206c6725e7bf63a0eac021046f9c1e8957d96b995b1533",
            patchedSHA256: "b754b3305564f2ddb579532ea0c072d67e0143c637b279298cb5382c023c432d",
            iidOffset: 0x339678,
            resizeSite: 0x28A560
        ),
        ReShadeBuild(
            version: "5.8.0",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_5.8.0.exe")!,
            setupSHA256: "bd9513b6d1cd50a02213549ab46f1b1f66c13c705b0e0515f45007d7b2e47d98",
            runtimeSHA256: "3bf46fafce509b4aba82cbe904d8453d468804669482ee72da0f6e0873a06ece",
            patchedSHA256: "bb5bf3370cdbb61ba941e281241b2589a81dd8d1d2881f428a0e0bb5c7321b26",
            iidOffset: 0x313E40,
            resizeSite: 0x265F80
        ),
        ReShadeBuild(
            version: "5.7.0",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_5.7.0.exe")!,
            setupSHA256: "d0f00824812b0e6ac45b84966165f9d4232e07dbcbec5de91ea1c5af2e001f61",
            runtimeSHA256: "08b380269b629706f4d91a44fdf2194683b1d907d314fcbfdbe4eda4dc628f11",
            patchedSHA256: "a1b84aa1356ba983e6f4107d02e00311065eb72fdb70187441a46b990bc4a68c",
            iidOffset: 0x311450,
            resizeSite: 0x263730
        ),
        ReShadeBuild(
            version: "5.6.0",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_5.6.0.exe")!,
            setupSHA256: "26a7cd9aae702866749a3dcfa342e3bb913212e5357a252bbee2e08f70ded4fc",
            runtimeSHA256: "f725b72f6f624f28845ab7b0e0151fac87b4d0f288b1a3fd5417c5d30046c549",
            patchedSHA256: "783509f61f0a350a102eadbdf49d5cfa2cd9c47219075d2de0a94308e83e96a4",
            iidOffset: 0x30E540,
            resizeSite: 0x2608A0
        ),
        ReShadeBuild(
            version: "5.5.2",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_5.5.2.exe")!,
            setupSHA256: "42bac664572623e6e4977ed99787cb67b814235d7ad1561167574b00c065a712",
            runtimeSHA256: "4323b3a8bababf174337d8a553e025194fec8350fe2809d3abe6a59ed532fd27",
            patchedSHA256: "ca54c71164e5b5522a5adc8627ab561221daacf258e5bfd7f80dd7b72cb40d48",
            iidOffset: 0x30CF68,
            resizeSite: 0x25F990
        ),
        ReShadeBuild(
            version: "5.4.2",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_5.4.2.exe")!,
            setupSHA256: "d438dbc778833747614b3f91e57454836b7ec80ce4ce8a1ee2565aafd5bdd000",
            runtimeSHA256: "0e19f14dd41f1f1e47c0ec15290a672ab4eba0b38751a400cd3609f62101455d",
            patchedSHA256: "562fde5b02c736d96ab726659f4f2567c1225384957239a9b4b8b37cc4673db7",
            iidOffset: 0x309330,
            resizeSite: 0x25BEC0
        ),
        ReShadeBuild(
            version: "5.3.0",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_5.3.0.exe")!,
            setupSHA256: "d08292644069ec0e48b9fa3c1125f637bf17b223dd2de3316d5787b2777c0c44",
            runtimeSHA256: "007105f07655c945babd653e04ee5a796a75c12d05833f0d50fd3f1c907fd19c",
            patchedSHA256: "167fdd7398891e774bb88ee8019b4c62b33343ab5a7a625543b1160b6e75be98",
            iidOffset: 0x303198,
            resizeSite: 0x255E50
        ),
        ReShadeBuild(
            version: "5.2.2",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_5.2.2.exe")!,
            setupSHA256: "9d9c67b81fc0bb2625c7511ea30755113840fa30870fbd676891fb4871ae2c76",
            runtimeSHA256: "2b79587724ca2788b1f7cc7aeaacd91e14778c6ce89a730bab3f346a1950561f",
            patchedSHA256: "bb0adeaf1d799a241ddc01c3927310094ca7f6e6e8abd9ccf7dfb8ce9d696bdf",
            iidOffset: 0x305288,
            resizeSite: 0x258730
        ),
        ReShadeBuild(
            version: "5.1.0",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_5.1.0.exe")!,
            setupSHA256: "7053b645084e3d4fa6cc00dbdf77a6bd69fb9adbab17ced398953bcd5586d74e",
            runtimeSHA256: "08d9ec44904e91c9181f233e292405c431da66636ae4fd1082d0d9f0d886d6f3",
            patchedSHA256: "afa3a0f76242bc69fd759d4635fa543a3f08cdde8484903bb01df907a7a6243f",
            iidOffset: 0x2FD9A8,
            resizeSite: 0x251300
        ),
        ReShadeBuild(
            version: "5.0.2",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_5.0.2.exe")!,
            setupSHA256: "f042c2bad918cddfcdfbb7b7859ed59ad1f7ac7284cd5c8d384ed6dc408d609d",
            runtimeSHA256: "584fac4d9fc327228e1cc32ac059acb4b9ca135f1d75a678124c282b24e3a7d7",
            patchedSHA256: "1d3b499560226507c6967c13e0733312824186ac281153b5dfe598fa41e67c9b",
            iidOffset: 0x301E68,
            resizeSite: 0x255A70
        ),
        ReShadeBuild(
            version: "5.0.0",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_5.0.0.exe")!,
            setupSHA256: "a4e822078469e88f37d27cdfb5abb1f0c841c7e4242df1df4ac6eabae0c8d9fe",
            runtimeSHA256: "d9472a68f53626dea077dcc1c03afcf5a3111ced4e9f9656b99e5adee743a5ff",
            patchedSHA256: "cc5878224e9f71ef5f8bb5cc8db39da230f70eb9be17c81a53cb6114a824a955",
            iidOffset: 0x301158,
            resizeSite: 0x254D90
        ),
        ReShadeBuild(
            version: "4.9.1",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_4.9.1.exe")!,
            setupSHA256: "b156f30c7add9bd8f9b82b94b96a70a4908ae5d7fe2f79243353ffad97afeca8",
            runtimeSHA256: "7520cb9170fca0f01f643c5fe5661f39421ea8d120a1e8fd2e8a387db6e7d3cc",
            patchedSHA256: "5206a2d7e260e04bfaf9da31523559a131f7c0c786b3d9e146eccfa535433a43",
            iidOffset: 0x2CDE90,
            resizeSite: 0x20A170
        ),
        ReShadeBuild(
            version: "4.8.2",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_4.8.2.exe")!,
            setupSHA256: "c5738502ccc3932e9bec5087e1fb1dbd5054dea0f8a235a9902438b457634a7a",
            runtimeSHA256: "3b75624dfb88149d0e0e7f332467858d31a0b31649bf2f562551ff7949b65f35",
            patchedSHA256: "5976d3a88b27833713d95e112a8719a14f5c17dae7cdce07099d09bcfe568635",
            iidOffset: 0x2ACCC0,
            resizeSite: 0x1EBF00
        ),
        ReShadeBuild(
            version: "4.7.0",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_4.7.0.exe")!,
            setupSHA256: "0e3ceba664256c7648a6a792a4be539aa23b6c6f1165898529d51d0ad1a8110c",
            runtimeSHA256: "28205140b368210fafc64f96aea135d9f3a27ba45ab5a33cc1926750643cfa47",
            patchedSHA256: "22ff952a5c4e649e5be6d3c49fff138409625f348b804971619f25839dc37e0a",
            iidOffset: 0x2827E0,
            resizeSite: 0x1C75C0
        ),
        ReShadeBuild(
            version: "4.6.1",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_4.6.1.exe")!,
            setupSHA256: "d156ba35853dcb4e630233c61ce8f5b6e8a0526bcb01bd345dae60c23c9effb0",
            runtimeSHA256: "32696801af665fee9a968893b67216f4957a85f1743bd9cf8c9b96afa4096923",
            patchedSHA256: "38ef9d8a7f75ce56b0ae90f25da71df9c89c23ea8e5550348dbfddf963f6f907",
            iidOffset: 0x27FE10,
            resizeSite: 0x1C4FE0
        ),
        ReShadeBuild(
            version: "4.5.4",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_4.5.4.exe")!,
            setupSHA256: "5f26ce490784c29688b2d4cef35d7cc056ba419847d5ab18737b854094f57d4a",
            runtimeSHA256: "bd0e3ebdcf7d0b5ec36c661d7f29d5b63952c09854c203ad7c52293e3b729e2b",
            patchedSHA256: "b757aa62cf778d7b97cae24d873128bf03f07cdcf014cf6f53c37be2913f6454",
            iidOffset: 0x26B370,
            resizeSite: 0x1B19E0
        ),
        ReShadeBuild(
            version: "4.4.2",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_4.4.2.exe")!,
            setupSHA256: "7f3536241c76179c8dd6a75752fe4ee7370372fed9464b84f3f4a444273eee72",
            runtimeSHA256: "e925f94e620da3eba909b61991f13ac7607ee2471c474a22716913002f2bc7f3",
            patchedSHA256: "71638166c61c078a41bd4dbd5cca66469046a646bb0fd6bb8c91dd88487bb407",
            iidOffset: 0x249B10,
            resizeSite: 0x192F30
        ),
        ReShadeBuild(
            version: "4.3.0",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_4.3.0.exe")!,
            setupSHA256: "bdd3c3b91eb893ed05f8fe01a6824d29667e7645a3188f3f1d75a1744b9a498b",
            runtimeSHA256: "6629f2c2644cc26584f67c1d77b5e8389782e05b4f420ff5ee2580983c3dc367",
            patchedSHA256: "dadbf305e3c731d105028c60243139018a1308415c675ffe35bb74ec1d20f8ad",
            iidOffset: 0x229408,
            resizeSite: 0x1749E0
        ),
        ReShadeBuild(
            version: "4.2.1",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_4.2.1.exe")!,
            setupSHA256: "536196201fd7753f2833c3a62ca44947a6ca7eb5ed14bc834d6fb0295073fbb6",
            runtimeSHA256: "140623c3118fd3f0870501cda6ed7ccabaf19bb82de1fa85d1ce679469a4cfad",
            patchedSHA256: "7c1e4e494d1a002f384de4f6a52a605ac7e30aeb6fc60b747f745188fc575c76",
            iidOffset: 0x21C5C0,
            resizeSite: 0x168450
        ),
        ReShadeBuild(
            version: "4.1.1",
            setupURL: URL(string: "https://reshade.me/downloads/ReShade_Setup_4.1.1.exe")!,
            setupSHA256: "4bbde07856d0d5321b50536176d594a35cb2a2de9f772947e2c09f8e54b16943",
            runtimeSHA256: "e7b0a1622f9bd33183b02e2e1c7ba38666f447daec8437aac80ea7d0172e8165",
            patchedSHA256: "bcd271b7b2630e7d09f820618aec483b958db3960acd4ce864269d08c1bfc145",
            iidOffset: 0x1D3208,
            resizeSite: 0x14CD70
        )
    ]
    static let shaderArchiveURL = URL(string: "https://github.com/crosire/reshade-shaders/archive/refs/heads/slim.zip")!
    static let manifestName = ".reshade-metal-install.json"

    private static var guardCodeTemplate: Data {
        data(hex: "443b81200100007539443b8924010000753085d274083b91480100007524448b5424284585d27409443b91300100007511448b542430443b9160010000750331c0c34889e044894018e9000000009090")
    }

    private struct InstallManifest: Codable {
        var formatVersion: Int
        var reshadeVersion: String
        var installedAt: Date
        var backupFolderName: String
        var installedNames: [String]
        var originalNames: [String]
    }

    static func validateGameExecutable(_ url: URL) throws {
        guard url.pathExtension.lowercased() == "exe" else {
            throw InstallerError.invalidExecutable("Select the Windows game's .exe file, not its folder or launcher shortcut.")
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw InstallerError.invalidExecutable("The selected .exe file does not exist.")
        }
        guard try is64BitPE(url) else { throw InstallerError.unsupportedArchitecture }
    }

    static func hasInstallation(in directory: URL) -> Bool {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directory.appendingPathComponent(manifestName).path) {
            return true
        }

        let configurationURL = directory.appendingPathComponent("ReShade.ini")
        if let contents = try? String(contentsOf: configurationURL, encoding: .utf8) {
            let lowered = contents.lowercased()
            if lowered.contains("effectsearchpaths=") &&
                (lowered.contains("texturesearchpaths=") || lowered.contains("presetpath=") || lowered.contains("noeffectcache=")) {
                return true
            }
        }

        let runtimeURL = directory.appendingPathComponent("dxgi.dll")
        if fileManager.fileExists(atPath: runtimeURL.path), (try? isReShadeRuntime(at: runtimeURL)) == true {
            return true
        }

        let presetURL = directory.appendingPathComponent("ReShadePreset.ini")
        let shaderDirectory = directory.appendingPathComponent("reshade-shaders/Shaders", isDirectory: true)
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: presetURL.path) &&
            fileManager.fileExists(atPath: shaderDirectory.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static func loadTechniques(in gameDirectory: URL) throws -> [ShaderTechnique] {
        let fileManager = FileManager.default
        let shaderDirectory = gameDirectory.appendingPathComponent("reshade-shaders/Shaders", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: shaderDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        let presetURL = gameDirectory.appendingPathComponent("ReShadePreset.ini")
        let presetContents = fileManager.fileExists(atPath: presetURL.path)
            ? try String(contentsOf: presetURL, encoding: .utf8)
            : ""
        let explicitlyEnabled = presetList("Techniques", in: presetContents)
        let enabledNames = Set(explicitlyEnabled ?? [])
        let sorting = presetList("TechniqueSorting", in: presetContents) ?? []
        let sortingOrder = Dictionary(sorting.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })

        let shaderFiles = (fileManager.enumerator(at: shaderDirectory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])?.allObjects ?? [])
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension.lowercased() == "fx" }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }

        let declarationPattern = try NSRegularExpression(pattern: "(?im)^[\\t ]*technique[\\t ]+([A-Za-z_][A-Za-z0-9_]*)\\b([^\\{]*)\\{")
        let commentsPattern = try NSRegularExpression(pattern: "(?s)/\\*.*?\\*/|//[^\\r\\n]*")
        let defaultEnabledPattern = try NSRegularExpression(pattern: "(?i)\\benabled\\s*=\\s*true\\b")
        var result: [ShaderTechnique] = []

        for shaderURL in shaderFiles {
            let contents = try String(contentsOf: shaderURL, encoding: .utf8)
            let fullRange = NSRange(contents.startIndex..<contents.endIndex, in: contents)
            let source = commentsPattern.stringByReplacingMatches(in: contents, range: fullRange, withTemplate: "")
            let sourceRange = NSRange(source.startIndex..<source.endIndex, in: source)
            for match in declarationPattern.matches(in: source, range: sourceRange) {
                guard let nameRange = Range(match.range(at: 1), in: source) else { continue }
                let name = String(source[nameRange])
                let id = "\(name)@\(shaderURL.lastPathComponent)"
                let annotations = Range(match.range(at: 2), in: source).map { String(source[$0]) } ?? ""
                let annotationRange = NSRange(annotations.startIndex..<annotations.endIndex, in: annotations)
                let enabledByDefault = defaultEnabledPattern.firstMatch(in: annotations, range: annotationRange) != nil
                let isEnabled: Bool
                if explicitlyEnabled != nil {
                    isEnabled = enabledNames.contains(id) || enabledNames.contains(name)
                } else {
                    isEnabled = enabledByDefault
                }
                result.append(ShaderTechnique(id: id, name: name, shaderFile: shaderURL.lastPathComponent, enabledByDefault: enabledByDefault, isEnabled: isEnabled))
            }
        }

        if !sortingOrder.isEmpty {
            result.sort { left, right in
                let leftOrder = sortingOrder[left.id] ?? sortingOrder[left.name] ?? Int.max
                let rightOrder = sortingOrder[right.id] ?? sortingOrder[right.name] ?? Int.max
                if leftOrder != rightOrder { return leftOrder < rightOrder }
                return left.id.localizedStandardCompare(right.id) == .orderedAscending
            }
        }
        return result
    }

    static func importShaderEffects(from sources: [URL], into gameDirectory: URL) throws -> Int {
        guard !sources.isEmpty else { return 0 }
        let fileManager = FileManager.default
        let shaderDirectory = gameDirectory.appendingPathComponent("reshade-shaders/Shaders", isDirectory: true)
        let existingTechniqueIDs = Set(try loadTechniques(in: gameDirectory).map(\.id))
        var plannedCopies: [(source: URL, relativePath: String)] = []
        let supportedExtensions: Set<String> = ["fx", "fxh"]

        for source in sources {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
                throw InstallerError.filesystemFailure("The selected effect no longer exists: \(source.lastPathComponent).")
            }
            if isDirectory.boolValue {
                guard let enumerator = fileManager.enumerator(at: source, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
                    throw InstallerError.filesystemFailure("Could not read the selected effects folder: \(source.path).")
                }
                for case let child as URL in enumerator {
                    guard supportedExtensions.contains(child.pathExtension.lowercased()),
                          (try? child.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                    let prefix = source.standardizedFileURL.path.hasSuffix("/") ? source.standardizedFileURL.path : source.standardizedFileURL.path + "/"
                    guard child.standardizedFileURL.path.hasPrefix(prefix) else { continue }
                    let relativePath = String(child.standardizedFileURL.path.dropFirst(prefix.count))
                    plannedCopies.append((child, relativePath))
                }
            } else {
                guard supportedExtensions.contains(source.pathExtension.lowercased()) else {
                    throw InstallerError.filesystemFailure("Choose ReShade .fx effect files, .fxh include files, or a folder containing them.")
                }
                plannedCopies.append((source, source.lastPathComponent))
            }
        }

        guard !plannedCopies.isEmpty else {
            throw InstallerError.filesystemFailure("No .fx effects or .fxh include files were found in the selection.")
        }

        let standardizedShaderDirectory = shaderDirectory.standardizedFileURL.path
        var destinationPaths = Set<String>()
        for item in plannedCopies {
            let components = item.relativePath.split(separator: "/")
            guard !item.relativePath.isEmpty,
                  !item.relativePath.hasPrefix("/"),
                  !components.contains(".."),
                  !components.contains(".") else {
                throw InstallerError.filesystemFailure("An effect has an invalid relative path: \(item.relativePath).")
            }
            let destination = shaderDirectory.appendingPathComponent(item.relativePath).standardizedFileURL
            guard destination.path.hasPrefix(standardizedShaderDirectory + "/") else {
                throw InstallerError.filesystemFailure("An effect path escapes this game's shader folder: \(item.relativePath).")
            }
            guard destinationPaths.insert(destination.path).inserted else {
                throw InstallerError.filesystemFailure("More than one selected file maps to \(item.relativePath). Select each effect only once.")
            }
            guard !fileManager.fileExists(atPath: destination.path) else {
                throw InstallerError.filesystemFailure("\(item.relativePath) already exists in this game's shader folder. Rename or remove the existing file before importing it.")
            }
        }

        let presetURL = gameDirectory.appendingPathComponent("ReShadePreset.ini")
        let hadPreset = fileManager.fileExists(atPath: presetURL.path)
        var copiedURLs: [URL] = []
        do {
            try fileManager.createDirectory(at: shaderDirectory, withIntermediateDirectories: true)
            for item in plannedCopies {
                let destination = shaderDirectory.appendingPathComponent(item.relativePath)
                try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.copyItem(at: item.source, to: destination)
                copiedURLs.append(destination)
            }

            if !hadPreset {
                try Data("Techniques=\nTechniqueSorting=\n".utf8).write(to: presetURL, options: .atomic)
            }

            var techniques = try loadTechniques(in: gameDirectory)
            techniques = techniques.map { technique in
                var updated = technique
                if !existingTechniqueIDs.contains(technique.id) {
                    updated.isEnabled = technique.enabledByDefault
                }
                return updated
            }
            try saveTechniqueStates(techniques, in: gameDirectory)
            return plannedCopies.count
        } catch {
            for copiedURL in copiedURLs.reversed() where fileManager.fileExists(atPath: copiedURL.path) {
                try? fileManager.removeItem(at: copiedURL)
            }
            if !hadPreset, fileManager.fileExists(atPath: presetURL.path) {
                try? fileManager.removeItem(at: presetURL)
            }
            throw error
        }
    }

    /// Imports a ReShade preset as this game's active preset. Any existing active preset is
    /// copied to a timestamped backup first, and unrelated ReShade.ini settings are preserved.
    static func importPreset(from source: URL, into gameDirectory: URL) throws -> String {
        let fileManager = FileManager.default
        guard source.pathExtension.lowercased() == "ini" else {
            throw InstallerError.filesystemFailure("Choose a ReShade preset with an .ini extension.")
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw InstallerError.filesystemFailure("The selected preset file no longer exists.")
        }

        let sourceData: Data
        let sourceContents: String
        do {
            sourceData = try Data(contentsOf: source)
            sourceContents = try String(contentsOf: source, encoding: .utf8)
        } catch {
            throw InstallerError.filesystemFailure("Could not read the selected preset as a UTF-8 INI file: \(error.localizedDescription)")
        }

        guard presetList("Techniques", in: sourceContents) != nil ||
                presetList("TechniqueSorting", in: sourceContents) != nil else {
            throw InstallerError.filesystemFailure("This INI file does not contain ReShade preset entries (Techniques= or TechniqueSorting=). Choose the preset .ini downloaded from Nexus Mods.")
        }

        let destination = gameDirectory.appendingPathComponent("ReShadePreset.ini")
        let configurationURL = gameDirectory.appendingPathComponent("ReShade.ini")
        guard fileManager.fileExists(atPath: configurationURL.path) else {
            throw InstallerError.filesystemFailure("ReShade.ini was not found in this game's folder. Install or repair ReShade for this game first.")
        }

        let configurationContents: String
        let configurationData: Data
        do {
            configurationData = try Data(contentsOf: configurationURL)
            configurationContents = try String(contentsOf: configurationURL, encoding: .utf8)
        } catch {
            throw InstallerError.filesystemFailure("Could not read this game's ReShade.ini: \(error.localizedDescription)")
        }

        let updatedConfiguration = configurationWithPresetPath(".\\ReShadePreset.ini", in: configurationContents)
        let sourcePath = source.standardizedFileURL.path
        let destinationPath = destination.standardizedFileURL.path
        let isAlreadyDestination = sourcePath == destinationPath
        let destinationExists = fileManager.fileExists(atPath: destination.path)
        var backupURL: URL?

        if destinationExists && !isAlreadyDestination {
            var candidate: URL
            repeat {
                candidate = gameDirectory.appendingPathComponent("ReShadePreset.backup-\(timestamp())-\(UUID().uuidString.prefix(6)).ini")
            } while fileManager.fileExists(atPath: candidate.path)
            do {
                try fileManager.copyItem(at: destination, to: candidate)
                backupURL = candidate
            } catch {
                throw InstallerError.filesystemFailure("The current preset could not be backed up, so the import was cancelled: \(error.localizedDescription)")
            }
        }

        let oldDestinationData = try? Data(contentsOf: destination)
        let oldConfigurationExists = fileManager.fileExists(atPath: configurationURL.path)
        do {
            if !isAlreadyDestination {
                try sourceData.write(to: destination, options: .atomic)
            }
            try Data(updatedConfiguration.utf8).write(to: configurationURL, options: .atomic)
        } catch {
            if let oldDestinationData {
                try? oldDestinationData.write(to: destination, options: .atomic)
            } else if !destinationExists && fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: destination)
            }
            if oldConfigurationExists {
                try? configurationData.write(to: configurationURL, options: .atomic)
            }
            throw InstallerError.filesystemFailure("Could not activate the selected preset. The previous files were restored where possible. \(error.localizedDescription)")
        }

        if let backupURL {
            return "Imported \(source.lastPathComponent) for \(gameDirectory.lastPathComponent). Previous preset backed up as \(backupURL.lastPathComponent)."
        }
        return "Activated \(source.lastPathComponent) for \(gameDirectory.lastPathComponent)."
    }

    private static func configurationWithPresetPath(_ presetPath: String, in contents: String) -> String {
        var lines = contents.components(separatedBy: .newlines)
        var generalStart: Int?
        var generalEnd = lines.count

        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            guard isINISectionHeader(trimmed) else { continue }
            if generalStart != nil {
                generalEnd = index
                break
            }
            if trimmed.dropFirst().dropLast().trimmingCharacters(in: .whitespaces).caseInsensitiveCompare("GENERAL") == .orderedSame {
                generalStart = index + 1
            }
        }

        if let generalStart {
            let range = generalStart..<generalEnd
            if let pathIndex = range.first(where: { index in
                guard let equals = lines[index].firstIndex(of: "=") else { return false }
                return lines[index][..<equals].trimmingCharacters(in: .whitespaces).caseInsensitiveCompare("PresetPath") == .orderedSame
            }) {
                lines[pathIndex] = "PresetPath=\(presetPath)"
            } else {
                lines.insert("PresetPath=\(presetPath)", at: generalEnd)
            }
        } else {
            if !lines.isEmpty && !(lines.last?.isEmpty ?? true) { lines.append("") }
            lines.append(contentsOf: ["[GENERAL]", "PresetPath=\(presetPath)"])
        }

        var updated = lines.joined(separator: "\n")
        if !updated.hasSuffix("\n") { updated.append("\n") }
        return updated
    }

    static func saveTechniqueStates(_ techniques: [ShaderTechnique], in gameDirectory: URL) throws {
        let fileManager = FileManager.default
        let presetURL = gameDirectory.appendingPathComponent("ReShadePreset.ini")
        guard fileManager.fileExists(atPath: presetURL.path) else {
            throw InstallerError.filesystemFailure("This game's ReShadePreset.ini was not found. Install ReShade for this game before changing shader states.")
        }

        let currentContents = try String(contentsOf: presetURL, encoding: .utf8)
        let existingEnabled = presetList("Techniques", in: currentContents) ?? []
        let existingSorting = presetList("TechniqueSorting", in: currentContents) ?? []
        let knownIdentifiers = Set(techniques.flatMap { [$0.id, $0.name] })
        let preservedEnabled = existingEnabled.filter { !knownIdentifiers.contains($0) }
        let preservedSorting = existingSorting.filter { !knownIdentifiers.contains($0) }
        // ReShade presets identify an effect as TechniqueName@ShaderFile.fx.
        let enabled = preservedEnabled + techniques.filter(\.isEnabled).map(\.id)
        let sorting = techniques.map(\.id) + preservedSorting

        var lines = currentContents.components(separatedBy: .newlines)
        var rootEnd = lines.firstIndex(where: isINISectionHeader) ?? lines.count
        setPresetList("Techniques", value: enabled, lines: &lines, rootEnd: &rootEnd)
        setPresetList("TechniqueSorting", value: sorting, lines: &lines, rootEnd: &rootEnd)
        var updated = lines.joined(separator: "\n")
        if !updated.hasSuffix("\n") { updated.append("\n") }
        try Data(updated.utf8).write(to: presetURL, options: .atomic)
    }

    private static func presetList(_ key: String, in contents: String) -> [String]? {
        let lines = contents.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if isINISectionHeader(trimmed) { break }
            guard let equals = trimmed.firstIndex(of: "=") else { continue }
            let foundKey = trimmed[..<equals].trimmingCharacters(in: .whitespaces)
            guard foundKey.caseInsensitiveCompare(key) == .orderedSame else { continue }
            let value = trimmed[trimmed.index(after: equals)...]
            return value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        return nil
    }

    private static func isINISectionHeader(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.hasPrefix("[") && trimmed.hasSuffix("]")
    }

    private static func setPresetList(_ key: String, value: [String], lines: inout [String], rootEnd: inout Int) {
        let replacement = "\(key)=\(value.joined(separator: ", "))"
        let rootRange = 0..<min(rootEnd, lines.count)
        if let index = rootRange.first(where: { lineIndex in
            guard let equals = lines[lineIndex].firstIndex(of: "=") else { return false }
            return lines[lineIndex][..<equals].trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(key) == .orderedSame
        }) {
            lines[index] = replacement
        } else {
            lines.insert(replacement, at: rootEnd)
            rootEnd += 1
        }
    }

    static func install(gameExecutable: URL, installShaders: Bool, reshadeVersion: String = defaultVersion, progress: @escaping @Sendable (String) -> Void) async throws -> String {
        try validateGameExecutable(gameExecutable)
        guard let build = supportedBuilds.first(where: { $0.version == reshadeVersion }) else {
            throw InstallerError.invalidDownload("ReShade \(reshadeVersion) does not have a verified D3DMetal patch profile. Choose one of the versions listed as compatible in the installer.")
        }
        let fileManager = FileManager.default
        let gameDirectory = gameExecutable.deletingLastPathComponent()
        let manifestURL = gameDirectory.appendingPathComponent(manifestName)
        guard !hasInstallation(in: gameDirectory) else { throw InstallerError.existingInstallation }

        progress("Downloading official ReShade \(build.version) setup…")
        let workingDirectory = fileManager.temporaryDirectory.appendingPathComponent("ReShadeMetal-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workingDirectory) }

        let installerURL = workingDirectory.appendingPathComponent("ReShade_Setup_\(build.version).exe")
        try await download(build.setupURL, to: installerURL)
        let setupHash = try sha256(of: installerURL)
        guard setupHash == build.setupSHA256 else {
            throw InstallerError.invalidDownload("The official ReShade setup SHA-256 did not match the verified \(build.version) build. The file was not installed.")
        }
        progress("Setup hash verified. Extracting the 64-bit runtime…")

        let extractDirectory = workingDirectory.appendingPathComponent("runtime", isDirectory: true)
        try fileManager.createDirectory(at: extractDirectory, withIntermediateDirectories: true)
        // ReShade's Windows setup is a self-extracting ZIP. Apple's bundled unzip
        // reports exit status 1 for the executable prefix even when extraction works;
        // the extracted DLL hash below is the authoritative integrity check.
        try run("/usr/bin/unzip", arguments: ["-oq", installerURL.path, "ReShade64.dll", "-d", extractDirectory.path], allowExitStatusOne: true)
        let extractedRuntime = extractDirectory.appendingPathComponent("ReShade64.dll")
        guard fileManager.fileExists(atPath: extractedRuntime.path), try sha256(of: extractedRuntime) == build.runtimeSHA256 else {
            throw InstallerError.invalidDownload("The extracted ReShade64.dll did not match the verified ReShade \(build.version) x64 runtime.")
        }

        progress("Applying checked D3DMetal and Wine shader-compiler compatibility patches…")
        let patchedDLL = try patchRuntime(at: extractedRuntime, output: workingDirectory.appendingPathComponent("dxgi.dll"), build: build)

        var stagedShaders: URL?
        if installShaders {
            progress("Downloading the official ReShade shader collection…")
            let shaderArchive = workingDirectory.appendingPathComponent("reshade-shaders.zip")
            try await download(shaderArchiveURL, to: shaderArchive)
            let shaderExtract = workingDirectory.appendingPathComponent("shader-extract", isDirectory: true)
            try fileManager.createDirectory(at: shaderExtract, withIntermediateDirectories: true)
            try run("/usr/bin/ditto", arguments: ["-x", "-k", shaderArchive.path, shaderExtract.path])
            guard let repository = try fileManager.contentsOfDirectory(at: shaderExtract, includingPropertiesForKeys: [.isDirectoryKey]).first(where: { candidate in
                var isDirectory: ObjCBool = false
                return fileManager.fileExists(atPath: candidate.appendingPathComponent("Shaders").path, isDirectory: &isDirectory) && isDirectory.boolValue
            }) else {
                throw InstallerError.invalidDownload("The downloaded shader archive did not contain the expected Shaders folder.")
            }
            let shaderRoot = workingDirectory.appendingPathComponent("reshade-shaders", isDirectory: true)
            try fileManager.createDirectory(at: shaderRoot, withIntermediateDirectories: true)
            try fileManager.copyItem(at: repository.appendingPathComponent("Shaders"), to: shaderRoot.appendingPathComponent("Shaders"))
            let textures = repository.appendingPathComponent("Textures")
            if fileManager.fileExists(atPath: textures.path) {
                try fileManager.copyItem(at: textures, to: shaderRoot.appendingPathComponent("Textures"))
            } else {
                try fileManager.createDirectory(at: shaderRoot.appendingPathComponent("Textures"), withIntermediateDirectories: true)
            }
            stagedShaders = shaderRoot
        }

        progress("Preparing backups and installation files…")
        let dxgiURL = gameDirectory.appendingPathComponent("dxgi.dll")
        let oldDXGIExists = fileManager.fileExists(atPath: dxgiURL.path)
        let oldDXGIIsReShade = oldDXGIExists ? try isReShadeRuntime(at: dxgiURL) : false
        let requiresProxy = oldDXGIExists && !oldDXGIIsReShade
        let chainedProxyURL = gameDirectory.appendingPathComponent("dxgi.original.dll")
        if requiresProxy && fileManager.fileExists(atPath: chainedProxyURL.path) {
            throw InstallerError.invalidExecutable("This game already has both dxgi.dll and dxgi.original.dll. That usually indicates an existing proxy chain; remove or document that setup before installing ReShade Metal so the chain is not overwritten.")
        }
        var originalNames = ["dxgi.dll", "ReShade.ini", "ReShadePreset.ini"]
        if installShaders { originalNames.append("reshade-shaders") }
        if requiresProxy { originalNames.append("dxgi.original.dll") }
        originalNames = originalNames.filter { fileManager.fileExists(atPath: gameDirectory.appendingPathComponent($0).path) }

        var installedNames = ["dxgi.dll", "ReShade.ini", "ReShadePreset.ini"]
        if installShaders { installedNames.append("reshade-shaders") }
        if requiresProxy { installedNames.append("dxgi.original.dll") }

        let backupFolderName = ".ReShadeMetalBackup-\(timestamp())-\(UUID().uuidString.prefix(6))"
        let backupRoot = gameDirectory.appendingPathComponent(backupFolderName, isDirectory: true)
        let originalsDirectory = backupRoot.appendingPathComponent("originals", isDirectory: true)
        try fileManager.createDirectory(at: originalsDirectory, withIntermediateDirectories: true)
        var movedNames: [String] = []
        var installedOrCopiedNames: [String] = []

        do {
            for name in originalNames {
                let liveURL = gameDirectory.appendingPathComponent(name)
                let backupURL = originalsDirectory.appendingPathComponent(name)
                try fileManager.moveItem(at: liveURL, to: backupURL)
                movedNames.append(name)
            }

            if requiresProxy {
                let priorDXGI = originalsDirectory.appendingPathComponent("dxgi.dll")
                guard fileManager.fileExists(atPath: priorDXGI.path) else { throw InstallerError.filesystemFailure("The pre-install dxgi.dll could not be found in the backup folder.") }
                try fileManager.copyItem(at: priorDXGI, to: gameDirectory.appendingPathComponent("dxgi.original.dll"))
                installedOrCopiedNames.append("dxgi.original.dll")
            }

            try fileManager.copyItem(at: patchedDLL, to: dxgiURL)
            installedOrCopiedNames.append("dxgi.dll")
            let ini = makeConfiguration(enableProxy: requiresProxy)
            try Data(ini.utf8).write(to: gameDirectory.appendingPathComponent("ReShade.ini"), options: .atomic)
            installedOrCopiedNames.append("ReShade.ini")
            let preset = "Techniques=\nTechniqueSorting=\n\n[GENERAL]\nEffectSearchPaths=.\\reshade-shaders\\Shaders\nTextureSearchPaths=.\\reshade-shaders\\Textures\n"
            try Data(preset.utf8).write(to: gameDirectory.appendingPathComponent("ReShadePreset.ini"), options: .atomic)
            installedOrCopiedNames.append("ReShadePreset.ini")
            if let stagedShaders {
                try fileManager.copyItem(at: stagedShaders, to: gameDirectory.appendingPathComponent("reshade-shaders", isDirectory: true))
                installedOrCopiedNames.append("reshade-shaders")
            }

            let manifest = InstallManifest(formatVersion: 1, reshadeVersion: build.version, installedAt: Date(), backupFolderName: backupFolderName, installedNames: installedNames, originalNames: originalNames)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        } catch {
            for name in installedOrCopiedNames.reversed() {
                let item = gameDirectory.appendingPathComponent(name)
                if fileManager.fileExists(atPath: item.path) { try? fileManager.removeItem(at: item) }
            }
            for name in movedNames.reversed() {
                let backup = originalsDirectory.appendingPathComponent(name)
                let live = gameDirectory.appendingPathComponent(name)
                if fileManager.fileExists(atPath: backup.path), !fileManager.fileExists(atPath: live.path) {
                    try? fileManager.moveItem(at: backup, to: live)
                }
            }
            throw error
        }

        progress("Installation complete. Your original files are backed up.")
        return "Installed ReShade \(build.version). Backup: \(backupFolderName) (hidden in the game folder)."
    }

    static func uninstall(gameExecutable: URL, progress: @escaping @Sendable (String) -> Void) throws -> String {
        try validateGameExecutable(gameExecutable)
        let fileManager = FileManager.default
        let gameDirectory = gameExecutable.deletingLastPathComponent()
        let manifestURL = gameDirectory.appendingPathComponent(manifestName)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            guard hasInstallation(in: gameDirectory) else {
                throw InstallerError.invalidExecutable("No ReShade installation or saved backup was found beside this game's executable.")
            }
            return try restoreDetectedInstallation(in: gameDirectory, progress: progress)
        }
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest: InstallManifest
        do { manifest = try JSONDecoder().decode(InstallManifest.self, from: manifestData) }
        catch { throw InstallerError.unsafeManifest }
        guard manifest.formatVersion == 1,
              manifest.backupFolderName.hasPrefix(".ReShadeMetalBackup-"),
              !manifest.backupFolderName.contains("/"),
              !manifest.backupFolderName.contains("\\"),
              manifest.installedNames.allSatisfy(allowedManagedName),
              manifest.originalNames.allSatisfy(allowedManagedName) else {
            throw InstallerError.unsafeManifest
        }

        let backupRoot = gameDirectory.appendingPathComponent(manifest.backupFolderName, isDirectory: true)
        let originalsDirectory = backupRoot.appendingPathComponent("originals", isDirectory: true)
        guard fileManager.fileExists(atPath: originalsDirectory.path) else { throw InstallerError.missingBackup(originalsDirectory.path) }
        for name in manifest.originalNames {
            guard fileManager.fileExists(atPath: originalsDirectory.appendingPathComponent(name).path) else {
                throw InstallerError.missingBackup(originalsDirectory.appendingPathComponent(name).path)
            }
        }

        progress("Removing installed ReShade files and preserving current copies…")
        let currentInstallDirectory = backupRoot.appendingPathComponent("installed-before-restore", isDirectory: true)
        try fileManager.createDirectory(at: currentInstallDirectory, withIntermediateDirectories: true)
        for name in manifest.installedNames {
            let live = gameDirectory.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: live.path) else { continue }
            let saved = currentInstallDirectory.appendingPathComponent(name)
            if fileManager.fileExists(atPath: saved.path) { try fileManager.removeItem(at: saved) }
            try fileManager.moveItem(at: live, to: saved)
        }

        do {
            for name in manifest.originalNames {
                let backup = originalsDirectory.appendingPathComponent(name)
                let live = gameDirectory.appendingPathComponent(name)
                if fileManager.fileExists(atPath: live.path) { try fileManager.removeItem(at: live) }
                try fileManager.copyItem(at: backup, to: live)
            }
            try fileManager.removeItem(at: manifestURL)
        } catch {
            // The backup remains intact if a restore fails, so the user can retry safely.
            throw InstallerError.filesystemFailure("Restore did not finish: \(error.localizedDescription). The backup remains at \(backupRoot.path).")
        }

        progress("Original files restored. The hidden backup folder has been retained.")
        return "Restored the pre-install files. Recovery copies remain in \(manifest.backupFolderName)."
    }

    private static func restoreDetectedInstallation(in gameDirectory: URL, progress: @escaping @Sendable (String) -> Void) throws -> String {
        let fileManager = FileManager.default
        let dxgiURL = gameDirectory.appendingPathComponent("dxgi.dll")
        let originalDXGIURL = gameDirectory.appendingPathComponent("dxgi.original.dll")
        let configurationURL = gameDirectory.appendingPathComponent("ReShade.ini")
        let currentConfiguration = (try? String(contentsOf: configurationURL, encoding: .utf8)) ?? ""
        let loweredConfiguration = currentConfiguration.lowercased()
        let proxyIsOriginal = loweredConfiguration.contains("enableproxylibrary=1") &&
            loweredConfiguration.contains("proxylibrary=") && loweredConfiguration.contains("dxgi.original.dll")
        let dxgiIsKnownRuntime = fileManager.fileExists(atPath: dxgiURL.path) && (try? isReShadeRuntime(at: dxgiURL)) == true
        let restoreOriginalDXGI = fileManager.fileExists(atPath: originalDXGIURL.path) && (proxyIsOriginal || dxgiIsKnownRuntime)

        let backupName = ".ReShadeMetalBackup-\(timestamp())-\(UUID().uuidString.prefix(6))"
        let backupRoot = gameDirectory.appendingPathComponent(backupName, isDirectory: true)
        let snapshotDirectory = backupRoot.appendingPathComponent("removed-installation", isDirectory: true)
        var namesToSnapshot = ["dxgi.dll", "ReShade.ini", "ReShadePreset.ini", "reshade-shaders"]
        if restoreOriginalDXGI { namesToSnapshot.append("dxgi.original.dll") }
        namesToSnapshot = namesToSnapshot.filter { fileManager.fileExists(atPath: gameDirectory.appendingPathComponent($0).path) }

        progress("ReShade was detected without an installer manifest. Saving a recovery copy before restoring the game folder…")
        try fileManager.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
        do {
            for name in namesToSnapshot {
                try fileManager.copyItem(at: gameDirectory.appendingPathComponent(name), to: snapshotDirectory.appendingPathComponent(name))
            }

            for name in ["dxgi.dll", "ReShade.ini", "ReShadePreset.ini", "reshade-shaders"] {
                let liveURL = gameDirectory.appendingPathComponent(name)
                if fileManager.fileExists(atPath: liveURL.path) { try fileManager.removeItem(at: liveURL) }
            }

            if restoreOriginalDXGI {
                try fileManager.copyItem(at: snapshotDirectory.appendingPathComponent("dxgi.original.dll"), to: dxgiURL)
                try fileManager.removeItem(at: originalDXGIURL)
            }
        } catch {
            throw InstallerError.filesystemFailure("Restore did not finish: \(error.localizedDescription). A recovery copy was saved at \(snapshotDirectory.path); inspect it before retrying.")
        }

        progress("Detected ReShade files removed. A recovery copy has been retained.")
        if restoreOriginalDXGI {
            return "Restored the saved dxgi.original.dll and removed detected ReShade files. Recovery copy: \(backupName)."
        }
        return "Removed detected ReShade files. No dxgi.original.dll proxy was configured, so the wrapper's DXGI fallback will be used. Recovery copy: \(backupName)."
    }

    private static func allowedManagedName(_ name: String) -> Bool {
        ["dxgi.dll", "dxgi.original.dll", "ReShade.ini", "ReShadePreset.ini", "reshade-shaders"].contains(name)
    }

    private static func makeConfiguration(enableProxy: Bool) -> String {
        var lines = [
            "[GENERAL]",
            "EffectSearchPaths=.\\reshade-shaders\\Shaders",
            "TextureSearchPaths=.\\reshade-shaders\\Textures",
            "PresetPath=.\\ReShadePreset.ini",
            "EnableProxyLibrary=\(enableProxy ? 1 : 0)",
            "ProxyLibrary=\(enableProxy ? "dxgi.original.dll" : "")",
            "NoDebugInfo=0",
            "NoEffectCache=0",
            "PerformanceMode=0",
            "SkipLoadingDisabledEffects=1",
            "",
            "[ADDON]",
            "DisabledAddons=Generic Depth,Effect Runtime Sync",
            "",
            "[INPUT]",
            "KeyOverlay=36,0,0,0",
            "",
            "[INSTALL]",
            "Logging=1",
            ""
        ]
        if enableProxy { lines.insert("; The existing DXGI library is preserved as dxgi.original.dll.", at: 1) }
        return lines.joined(separator: "\n")
    }

    static func patchRuntime(at sourceURL: URL, output outputURL: URL) throws -> URL {
        guard let build = supportedBuilds.first(where: { $0.version == defaultVersion }) else {
            throw InstallerError.patchMismatch("The default ReShade build profile is missing.")
        }
        return try patchRuntime(at: sourceURL, output: outputURL, build: build)
    }

    static func patchRuntime(at sourceURL: URL, output outputURL: URL, build: ReShadeBuild) throws -> URL {
        let source = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
        guard digest(source) == build.runtimeSHA256 else {
            throw InstallerError.patchMismatch("The source runtime hash was unexpected. The patch was not applied.")
        }

        let expectedIID = data(hex: "378c5ca0c6d23247b3a09ce0b0dc9ae6")
        let expectedInstructions = data(hex: "488bc444894018")
        let guardCode = guardCodeTemplate
        guard source.count >= 0x40,
              source[0] == 0x4D, source[1] == 0x5A,
              build.iidOffset >= 0, build.iidOffset <= source.count - expectedIID.count,
              build.resizeSite >= 0, build.resizeSite <= source.count - expectedInstructions.count,
              source.subdata(in: build.iidOffset..<(build.iidOffset + expectedIID.count)) == expectedIID,
              source.subdata(in: build.resizeSite..<(build.resizeSite + expectedInstructions.count)) == expectedInstructions else {
            throw InstallerError.patchMismatch("The ReShade runtime no longer matches the inspected patch locations. Nothing was patched.")
        }

        let peOffset = Int(readUInt32(source, at: 0x3C))
        guard peOffset >= 0x40, peOffset <= source.count - 24,
              source[peOffset] == 0x50, source[peOffset + 1] == 0x45,
              source[peOffset + 2] == 0, source[peOffset + 3] == 0,
              readUInt16(source, at: peOffset + 4) == 0x8664 else {
            throw InstallerError.patchMismatch("The verified ReShade runtime has an invalid PE signature or architecture.")
        }
        let sectionCount = Int(readUInt16(source, at: peOffset + 6))
        let optionalHeaderOffset = peOffset + 24
        let optionalHeaderSize = Int(readUInt16(source, at: peOffset + 20))
        guard optionalHeaderSize >= 112,
              optionalHeaderOffset <= source.count - optionalHeaderSize,
              readUInt16(source, at: optionalHeaderOffset) == 0x20B,
              sectionCount > 0, sectionCount < Int(UInt16.max) else {
            throw InstallerError.patchMismatch("The verified ReShade runtime has an unsupported PE header layout.")
        }

        let sectionTableOffset = optionalHeaderOffset + optionalHeaderSize
        guard sectionTableOffset <= source.count - sectionCount * 40 else {
            throw InstallerError.patchMismatch("The ReShade section table is truncated.")
        }
        let sizeOfHeaders = Int(readUInt32(source, at: optionalHeaderOffset + 60))
        let sectionAlignment = Int(readUInt32(source, at: optionalHeaderOffset + 32))
        let fileAlignment = Int(readUInt32(source, at: optionalHeaderOffset + 36))
        let oldSizeOfImage = Int(readUInt32(source, at: optionalHeaderOffset + 56))
        let oldSizeOfCode = Int(readUInt32(source, at: optionalHeaderOffset + 4))
        guard sectionAlignment > 0, fileAlignment > 0,
              sectionAlignment <= 0x100000, fileAlignment <= 0x100000 else {
            throw InstallerError.patchMismatch("The ReShade PE alignment values are invalid.")
        }

        var sections: [(name: String, virtualSize: Int, virtualAddress: Int, rawSize: Int, rawPointer: Int, characteristics: UInt32)] = []
        for index in 0..<sectionCount {
            let headerOffset = sectionTableOffset + index * 40
            let rawName = Array(source[headerOffset..<(headerOffset + 8)].prefix { $0 != 0 })
            let name = String(bytes: rawName, encoding: .ascii) ?? ""
            sections.append((
                name: name,
                virtualSize: Int(readUInt32(source, at: headerOffset + 8)),
                virtualAddress: Int(readUInt32(source, at: headerOffset + 12)),
                rawSize: Int(readUInt32(source, at: headerOffset + 16)),
                rawPointer: Int(readUInt32(source, at: headerOffset + 20)),
                characteristics: readUInt32(source, at: headerOffset + 36)
            ))
        }
        guard !sections.contains(where: { $0.name == ".rguard" }),
              let textSection = sections.first(where: { $0.name == ".text" }),
              build.resizeSite >= textSection.rawPointer else {
            throw InstallerError.patchMismatch("The ReShade runtime already contains the guard section or has no compatible code section.")
        }

        // The font workaround is discovered semantically from the IID bytes, not
        // from a ReShade-version-specific file offset. Only patch copies stored in
        // non-executable PE sections; old builds without this IID need no change.
        let device1IID = data(hex: "29fb4ba0ef08d643a49ca9bdbdcbe686")
        let device1IIDMatches = occurrences(of: device1IID, in: source)
        let device1QueryOffsets = device1IIDMatches.filter { offset in
            sections.contains { section in
                let sectionEnd = section.rawPointer + section.rawSize
                return section.rawSize > 0 && section.rawPointer >= 0 &&
                    sectionEnd >= section.rawPointer && sectionEnd <= source.count &&
                    offset >= section.rawPointer && offset <= sectionEnd - device1IID.count &&
                    section.name != ".text" && (section.characteristics & 0x20000000) == 0
            }
        }
        guard device1IIDMatches.count == device1QueryOffsets.count else {
            throw InstallerError.patchMismatch("The Device1 IID was found outside a safe non-executable PE data section. Nothing was patched.")
        }
        let siteOffsetInText = build.resizeSite - textSection.rawPointer
        guard siteOffsetInText >= 0,
              siteOffsetInText + expectedInstructions.count <= min(textSection.virtualSize, textSection.rawSize) else {
            throw InstallerError.patchMismatch("The ResizeBuffers patch site is outside the declared executable section.")
        }
        let resizeRVA = textSection.virtualAddress + siteOffsetInText

        let newSectionHeaderOffset = sectionTableOffset + sectionCount * 40
        let firstRawPointer = sections.filter { $0.rawSize > 0 }.map(\.rawPointer).min() ?? source.count
        guard newSectionHeaderOffset + 40 <= sizeOfHeaders,
              newSectionHeaderOffset + 40 <= firstRawPointer,
              source.subdata(in: newSectionHeaderOffset..<(newSectionHeaderOffset + 40)).allSatisfy({ $0 == 0 }) else {
            throw InstallerError.patchMismatch("There is no safe room in the PE headers for a dedicated executable patch section.")
        }

        let maximumSectionEnd = sections.map { $0.virtualAddress + max($0.virtualSize, $0.rawSize) }.max() ?? oldSizeOfImage
        let guardRVA = align(max(oldSizeOfImage, maximumSectionEnd), to: sectionAlignment)
        let guardRawPointer = align(source.count, to: fileAlignment)
        let guardRawSize = align(guardCode.count, to: fileAlignment)
        guard guardRVA <= Int(UInt32.max) - guardCode.count,
              guardRawPointer <= Int(UInt32.max) - guardRawSize,
              oldSizeOfCode <= Int(UInt32.max) - guardRawSize else {
            throw InstallerError.patchMismatch("The new executable patch section exceeds PE format limits.")
        }

        var insertedGuard = guardCode
        let jumpPattern = data(hex: "e900000000")
        guard let guardJumpRange = insertedGuard.range(of: jumpPattern, options: .backwards) else {
            throw InstallerError.patchMismatch("The internal patch guard was invalid.")
        }
        let guardJumpOffset = guardJumpRange.lowerBound
        guard let guardReturnDisplacement = Int32(exactly: (resizeRVA + expectedInstructions.count) - (guardRVA + guardJumpOffset + 5)),
              let hookDisplacement = Int32(exactly: guardRVA - (resizeRVA + 5)) else {
            throw InstallerError.patchMismatch("The PE patch branch is outside the supported relative-jump range.")
        }
        insertedGuard.replaceSubrange((guardJumpOffset + 1)..<(guardJumpOffset + 5), with: littleEndian(guardReturnDisplacement))

        var bytes = source
        bytes[build.iidOffset] ^= 1
        var branch = Data([0xE9])
        branch.append(contentsOf: littleEndian(hookDisplacement))
        branch.append(contentsOf: [0x90, 0x90])
        bytes.replaceSubrange(build.resizeSite..<(build.resizeSite + expectedInstructions.count), with: branch)
        if bytes.count < guardRawPointer {
            bytes.append(Data(repeating: 0, count: guardRawPointer - bytes.count))
        }
        bytes.append(contentsOf: insertedGuard)
        bytes.append(Data(repeating: 0, count: guardRawSize - insertedGuard.count))

        var newSectionHeader = Data(repeating: 0, count: 40)
        newSectionHeader.replaceSubrange(0..<7, with: Data(".rguard".utf8))
        writeUInt32(UInt32(insertedGuard.count), into: &newSectionHeader, at: 8)
        writeUInt32(UInt32(guardRVA), into: &newSectionHeader, at: 12)
        writeUInt32(UInt32(guardRawSize), into: &newSectionHeader, at: 16)
        writeUInt32(UInt32(guardRawPointer), into: &newSectionHeader, at: 20)
        writeUInt32(0x60000020, into: &newSectionHeader, at: 36) // code, readable, executable
        bytes.replaceSubrange(newSectionHeaderOffset..<(newSectionHeaderOffset + 40), with: newSectionHeader)
        writeUInt16(UInt16(sectionCount + 1), into: &bytes, at: peOffset + 6)
        writeUInt32(UInt32(oldSizeOfCode + guardRawSize), into: &bytes, at: optionalHeaderOffset + 4)
        writeUInt32(UInt32(align(guardRVA + insertedGuard.count, to: sectionAlignment)), into: &bytes, at: optionalHeaderOffset + 56)
        writeUInt32(0, into: &bytes, at: optionalHeaderOffset + 64) // PE checksum is stale after patching.

        // Hash the standard patch before applying the optional IID adjustment.
        // Older profiles' known output hashes describe that baseline, while the
        // two already-verified 6.x outputs include the IID adjustment themselves.
        let baselinePatchedHash = digest(bytes)
        for offset in device1QueryOffsets {
            bytes[offset] ^= 1
        }
        let actualPatchedHash = digest(bytes)
        guard actualPatchedHash == build.patchedSHA256 || baselinePatchedHash == build.patchedSHA256 else {
            throw InstallerError.patchMismatch("ReShade \(build.version) patched output did not match its verified baseline. Expected \(build.patchedSHA256), got \(actualPatchedHash). The file was discarded.")
        }
        try patchWineFastoptEmission(in: &bytes, sections: sections)
        try bytes.write(to: outputURL, options: .atomic)
        return outputURL
    }

    private static func patchWineFastoptEmission(
        in bytes: inout Data,
        sections: [(name: String, virtualSize: Int, virtualAddress: Int, rawSize: Int, rawPointer: Int, characteristics: UInt32)]
    ) throws {
        let fastoptTemplate = Data("[fastopt] ".utf8)
        let loopTemplate = Data("[loop]    ".utf8)
        guard fastoptTemplate.count == loopTemplate.count else {
            throw InstallerError.patchMismatch("The Wine shader-compiler compatibility template has an invalid size.")
        }

        let matches = occurrences(of: fastoptTemplate, in: bytes)
        let safeMatches = matches.filter { offset in
            sections.contains { section in
                let sectionEnd = section.rawPointer + section.rawSize
                let isReadOnlyData = (section.characteristics & 0x40000000) != 0 &&
                    (section.characteristics & (0x80000000 | 0x20000000)) == 0
                return isReadOnlyData && section.rawSize > 0 && section.rawPointer >= 0 &&
                    sectionEnd >= section.rawPointer && sectionEnd <= bytes.count &&
                    offset >= section.rawPointer && offset <= sectionEnd - fastoptTemplate.count
            }
        }
        guard matches.count == safeMatches.count else {
            throw InstallerError.patchMismatch("The ReShade shader-compiler template was found outside a read-only data section. Nothing was written.")
        }
        // Some older supported ReShade builds do not contain this HLSL template.
        // In those builds there is no Wine fastopt emission to rewrite.
        for offset in safeMatches {
            bytes.replaceSubrange(offset..<(offset + fastoptTemplate.count), with: loopTemplate)
        }
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8) | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
    }

    private static func writeUInt16(_ value: UInt16, into data: inout Data, at offset: Int) {
        data[offset] = UInt8(truncatingIfNeeded: value)
        data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    }

    private static func writeUInt32(_ value: UInt32, into data: inout Data, at offset: Int) {
        data[offset] = UInt8(truncatingIfNeeded: value)
        data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
        data[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
        data[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
    }

    private static func align(_ value: Int, to alignment: Int) -> Int {
        ((value + alignment - 1) / alignment) * alignment
    }

    private static func isReShadeRuntime(at url: URL) throws -> Bool {
        let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
        let fileHash = digest(bytes)
        // Only recognize builds whose identity is known. A broad string scan could
        // mistake an unrelated DXGI proxy for ReShade and silently skip chaining it.
        // A runtime patched by this installer may have a different hash when the
        // discovered Device1 IID was adjusted, so also validate its guard section.
        return supportedBuilds.contains { fileHash == $0.patchedSHA256 || fileHash == $0.runtimeSHA256 } ||
            hasInstallerGuardSection(in: bytes)
    }

    private static func hasInstallerGuardSection(in bytes: Data) -> Bool {
        guard bytes.count >= 0x40, bytes[0] == 0x4D, bytes[1] == 0x5A else { return false }
        let peOffset = Int(readUInt32(bytes, at: 0x3C))
        guard peOffset >= 0x40, peOffset <= bytes.count - 24,
              bytes[peOffset] == 0x50, bytes[peOffset + 1] == 0x45,
              bytes[peOffset + 2] == 0, bytes[peOffset + 3] == 0 else { return false }

        let sectionCount = Int(readUInt16(bytes, at: peOffset + 6))
        let optionalHeaderOffset = peOffset + 24
        let optionalHeaderSize = Int(readUInt16(bytes, at: peOffset + 20))
        guard optionalHeaderSize >= 112,
              optionalHeaderOffset <= bytes.count - optionalHeaderSize,
              readUInt16(bytes, at: optionalHeaderOffset) == 0x20B,
              sectionCount > 0 else { return false }

        let sectionTableOffset = optionalHeaderOffset + optionalHeaderSize
        guard sectionCount <= (bytes.count - sectionTableOffset) / 40 else { return false }
        let template = guardCodeTemplate
        let jumpTemplate = data(hex: "e900000000")
        guard let jumpRange = template.range(of: jumpTemplate, options: .backwards) else { return false }

        for sectionIndex in 0..<sectionCount {
            let headerOffset = sectionTableOffset + sectionIndex * 40
            let rawName = Array(bytes[headerOffset..<(headerOffset + 8)].prefix { $0 != 0 })
            guard String(bytes: rawName, encoding: .ascii) == ".rguard" else { continue }

            let virtualSize = Int(readUInt32(bytes, at: headerOffset + 8))
            let rawSize = Int(readUInt32(bytes, at: headerOffset + 16))
            let rawPointer = Int(readUInt32(bytes, at: headerOffset + 20))
            let characteristics = readUInt32(bytes, at: headerOffset + 36)
            guard virtualSize == template.count,
                  rawSize >= template.count,
                  rawPointer >= 0, rawPointer <= bytes.count - template.count,
                  characteristics == 0x60000020 else { return false }

            for index in 0..<template.count {
                // The relative return displacement is filled for each runtime.
                if index > jumpRange.lowerBound && index < jumpRange.lowerBound + 5 { continue }
                if bytes[rawPointer + index] != template[index] { return false }
            }
            return true
        }
        return false
    }

    private static func is64BitPE(_ url: URL) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let dosHeader = try handle.read(upToCount: 64) ?? Data()
        guard dosHeader.count >= 64, dosHeader[0] == 0x4D, dosHeader[1] == 0x5A else {
            throw InstallerError.invalidExecutable("The selected file is not a Windows PE executable. Choose the game's .exe from its bottle.")
        }
        let peOffset = UInt32(dosHeader[0x3C]) | (UInt32(dosHeader[0x3D]) << 8) | (UInt32(dosHeader[0x3E]) << 16) | (UInt32(dosHeader[0x3F]) << 24)
        guard peOffset < 64 * 1024 * 1024 else { throw InstallerError.invalidExecutable("The selected file has an invalid PE header.") }
        try handle.seek(toOffset: UInt64(peOffset))
        let peHeader = try handle.read(upToCount: 6) ?? Data()
        guard peHeader.count == 6, peHeader[0] == 0x50, peHeader[1] == 0x45, peHeader[2] == 0, peHeader[3] == 0 else {
            throw InstallerError.invalidExecutable("The selected file has an invalid Windows PE signature.")
        }
        let machine = UInt16(peHeader[4]) | (UInt16(peHeader[5]) << 8)
        return machine == 0x8664
    }

    private static func download(_ url: URL, to destination: URL) async throws {
        do {
            let (temporaryURL, response) = try await URLSession.shared.download(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                throw InstallerError.downloadFailure("Download failed for \(url.host ?? url.absoluteString).")
            }
            if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
        } catch let error as InstallerError {
            throw error
        } catch {
            throw InstallerError.downloadFailure("Could not download \(url.host ?? url.absoluteString): \(error.localizedDescription)")
        }
    }

    @discardableResult
    private static func run(_ executable: String, arguments: [String], allowExitStatusOne: Bool = false) throws -> String {
        guard FileManager.default.isExecutableFile(atPath: executable) else { throw InstallerError.missingTool(executable) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        do { try process.run() }
        catch { throw InstallerError.processFailure("Could not start \(executable): \(error.localizedDescription)") }
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let stdout = String(data: outputData, encoding: .utf8) ?? ""
        let stderr = String(data: errorData, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 || (allowExitStatusOne && process.terminationStatus == 1) else {
            throw InstallerError.processFailure("\(URL(fileURLWithPath: executable).lastPathComponent) failed: \(stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? stdout : stderr)")
        }
        return stdout
    }

    private static func sha256(of url: URL) throws -> String {
        digest(try Data(contentsOf: url, options: .mappedIfSafe))
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func data(hex: String) -> Data {
        var result = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return Data() }
            result.append(byte)
            index = next
        }
        return result
    }

    private static func occurrences(of needle: Data, in haystack: Data) -> [Int] {
        guard !needle.isEmpty, needle.count <= haystack.count else { return [] }
        var result: [Int] = []
        var searchStart = haystack.startIndex
        while searchStart <= haystack.endIndex - needle.count,
              let range = haystack.range(of: needle, options: [], in: searchStart..<haystack.endIndex) {
            result.append(range.lowerBound)
            searchStart = range.lowerBound + needle.count
        }
        return result
    }

    private static func littleEndian(_ value: Int32) -> Data {
        var encoded = value.littleEndian
        return withUnsafeBytes(of: &encoded) { Data($0) }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
