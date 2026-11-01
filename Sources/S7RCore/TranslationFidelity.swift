import Foundation

public enum TranslationFidelity {
    public static func addsDayPeriod(source: String, translation: String) -> Bool {
        func containsPeriod(_ text: String) -> Bool {
            let lower = text.lowercased()
            let terms = ["오전", "오후", "아침", "저녁", "새벽", "정오", "午前", "午後", "上午", "下午", "早上", "晚上", "凌晨", "中午", "a.m.", "p.m."]
            if terms.contains(where: lower.contains) { return true }
            return lower.range(of: #"\b(morning|afternoon|evening|night|dawn|noon)\b|\b\d+\s*(am|pm)\b"#, options: .regularExpression) != nil
        }
        return !containsPeriod(source) && containsPeriod(translation)
    }
}
