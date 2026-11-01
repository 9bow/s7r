import Foundation
import Speech
import Translation

@main struct Probe {
 static func main() async {
  print("speechAvailable=\(SpeechTranscriber.isAvailable)")
  for tag in ["ko-KR", "en-US", "ja-JP", "zh-CN", "zh-TW", "es-ES"] {
   guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: tag)) else {
    print("speech \(tag): unsupported"); continue
   }
   let module = SpeechTranscriber(locale: locale, preset: .timeIndexedProgressiveTranscription)
   print("speech \(tag): \(locale.identifier) \(await AssetInventory.status(forModules: [module]))")
  }
  let availability = LanguageAvailability()
  for source in ["ko", "en", "ja", "zh-Hans", "zh-Hant"] {
   for target in ["ko", "en", "ja", "zh-Hans", "zh-Hant"] where source != target {
    print("translation \(source)>\(target): \(await availability.status(from: Locale.Language(identifier: source), to: Locale.Language(identifier: target)))")
   }
  }
  let source = Locale.Language(identifier: "en")
  let target = Locale.Language(identifier: "ko")
  if await availability.status(from: source, to: target) == .installed {
   do {
    let session = TranslationSession(installedSource: source, target: target)
    print("translation example: \(try await session.translate("Hello. This is a local subtitle test.").targetText)")
   } catch { print("translation error: \(error)") }
  }
 }
}
