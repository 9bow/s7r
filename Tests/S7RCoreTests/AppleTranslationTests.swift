import Foundation
import S7RCore
import S7RPlatform
import Testing

@Test(.enabled(if: ProcessInfo.processInfo.environment["S7R_TEST_APPLE_TRANSLATION"] == "1"))
func appleTranslationRecoversAfterCancellation() async throws {
    let status = await AppleTranslator.status(from: .ko, to: .en, script: .simplified)
    try #require(status == "installed", "Prepare Korean-to-English Apple Translation packs before this test.")
    let translator = AppleTranslator()
    let source = "안녕하세요. 이것은 로컬 자막 테스트입니다."
    let start = Date()
    let expected = try await translator.translate(source, from: .ko, to: .en, script: .simplified)
    print("Initial translation seconds: \(Date().timeIntervalSince(start))")
    let work = Task {
        do {
            _ = try await translator.translate(String(repeating: source, count: 200), from: .ko, to: .en, script: .simplified)
            return false
        } catch { return Task.isCancelled }
    }
    try await Task.sleep(for: .milliseconds(200))
    let cancellationStart = Date()
    work.cancel()
    #expect(await work.value, "The translation must still be active when cancellation arrives.")
    let cancellationSeconds = Date().timeIntervalSince(cancellationStart)
    print("Cancellation seconds: \(cancellationSeconds)")
    #expect(cancellationSeconds < 5, "Cancellation must return without waiting for the OS translation result.")
    let recovered = try await translator.translate(source, from: .ko, to: .en, script: .simplified)
    #expect(recovered == expected)
}
