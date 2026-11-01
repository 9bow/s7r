import CryptoKit
import Foundation
import S7RCore

public struct ModelFile: Codable, Sendable {
    public let path: String
    public let url: String
    public let bytes: Int64
    public let sha256: String?
}
public struct ModelInfo: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let revision: String
    public let license: String
    public let downloadBytes: Int64
    public let files: [ModelFile]
}
public enum ModelStore {
    public static var catalog: [ModelInfo] {
        get throws {
            guard let url = Bundle.module.url(forResource: "models", withExtension: "json") else { throw S7RError("Model catalog is missing.") }
            return try JSONDecoder().decode([ModelInfo].self, from: Data(contentsOf: url))
        }
    }
    public static func model(_ id: String) throws -> ModelInfo {
        guard let result = try catalog.first(where: { $0.id == id }) else { throw S7RError("Unknown model: \(id)") }
        return result
    }
    public static func installed(_ id: String, root: URL) -> Bool {
        guard let info = try? model(id), let receipt = try? Data(contentsOf: root.appendingPathComponent("\(id).installed.json")), let installed = try? JSONDecoder().decode(ModelInfo.self, from: receipt), installed.revision == info.revision else { return false }
        return info.files.allSatisfy { item in
            let attributes = try? FileManager.default.attributesOfItem(atPath: root.appendingPathComponent(item.path).path)
            return (attributes?[.size] as? NSNumber)?.int64Value == item.bytes
        }
    }
    public static func require(_ id: String, root: URL) throws {
        guard installed(id, root: root) else { throw S7RError("Model \(id) is missing or incomplete at \(root.path). Select Install in the GUI or use `s7r install-model \(id) --accept-license`. No download started.") }
    }
    private static func digest(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var digest = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty { digest.update(data: data) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
    public static func install(_ id: String, root: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        let model = try model(id)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var completed: Int64 = 0
        for file in model.files {
            try Task.checkCancellation()
            guard !file.path.split(separator: "/").contains(".."), let url = URL(string: file.url), url.scheme == "https", url.host == "huggingface.co" else { throw S7RError("Invalid model manifest.") }
            let target = root.appendingPathComponent(file.path)
            let (temporary, response) = try await session.download(from: url)
            defer { try? FileManager.default.removeItem(at: temporary) }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw S7RError("Model download failed: \(file.path)") }
            let size = try FileManager.default.attributesOfItem(atPath: temporary.path)[.size] as? NSNumber
            guard size?.int64Value == file.bytes else { throw S7RError("Model download size mismatch: \(file.path)") }
            if let expected = file.sha256, try digest(temporary) != expected { throw S7RError("Model SHA-256 mismatch: \(file.path)") }
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
            try FileManager.default.moveItem(at: temporary, to: target)
            completed += file.bytes
            progress(Double(completed) / Double(model.downloadBytes))
        }
        try JSONEncoder().encode(model).write(to: root.appendingPathComponent("\(id).installed.json"), options: .atomic)
    }
}
