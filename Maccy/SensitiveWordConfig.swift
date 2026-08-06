import Foundation
import SwiftUI
import Defaults

// MARK: - 敏感词配置模型

struct SensitiveWord: Identifiable, Codable, Hashable, Defaults.Serializable {
  var id: UUID = UUID()
  var word: String
  var replacement: String?  // 自定义替换词，nil 时使用自动编码
  
  init(id: UUID = UUID(), word: String, replacement: String? = nil) {
    self.id = id
    self.word = word
    self.replacement = replacement
  }
}

// MARK: - 敏感页面规则

struct SensitivePage: Identifiable, Codable, Hashable, Defaults.Serializable {
  var id: UUID = UUID()
  var urlPattern: String      // URL 匹配模式
  var titlePattern: String?    // 标题匹配模式
  var note: String?            // 备注说明
  
  init(id: UUID = UUID(), urlPattern: String, titlePattern: String? = nil, note: String? = nil) {
    self.id = id
    self.urlPattern = urlPattern
    self.titlePattern = titlePattern
    self.note = note
  }
}

// MARK: - 支持的浏览器应用

struct SupportedApp: Identifiable, Codable, Hashable, Defaults.Serializable {
  var id: String { bundleID }
  var bundleID: String        // macOS bundle identifier
  var name: String             // 显示名称
  var enabled: Bool            // 是否启用
  
  static let defaults: [SupportedApp] = [
    SupportedApp(bundleID: "com.google.Chrome", name: "Google Chrome", enabled: true),
    SupportedApp(bundleID: "com.microsoft.edgemac", name: "Microsoft Edge", enabled: true),
    SupportedApp(bundleID: "com.brave.Browser", name: "Brave Browser", enabled: true),
    SupportedApp(bundleID: "company.thebrowser.Browser", name: "Arc Browser", enabled: true),
    SupportedApp(bundleID: "com.apple.Safari", name: "Safari", enabled: false),
    SupportedApp(bundleID: "com.googlecode.iterm2", name: "iTerm2", enabled: false),
    SupportedApp(bundleID: "com.jetbrains.codex", name: "Codex", enabled: true),
    SupportedApp(bundleID: "com.todesktop.23031353043909097", name: "Cursor", enabled: true),
    SupportedApp(bundleID: "com.microsoft.VSCode", name: "VS Code", enabled: true),
    SupportedApp(bundleID: "com.figma.Desktop", name: "Figma", enabled: false),
  ]
}

// MARK: - 主配置

struct SensitiveWordConfig: Codable, Defaults.Serializable {
  var enabled: Bool = true
  var useAutoEncoding: Bool = true     // true=可还原的Base64编码, false=*号掩码
  var sensitiveWords: [SensitiveWord] = []
  var sensitivePages: [SensitivePage] = []
  var enabledApps: [SupportedApp] = SupportedApp.defaults

  private static let encodingPrefix = "__MACCY_B64_"
  private static let encodingSuffix = "__"
  
  // 主流 AI Chat 网页默认配置
  static let defaultAIPages: [SensitivePage] = [
    SensitivePage(urlPattern: "chat.openai.com", note: "ChatGPT"),
    SensitivePage(urlPattern: "chatgpt.com", note: "ChatGPT (新版)"),
    SensitivePage(urlPattern: "claude.ai", note: "Claude AI"),
    SensitivePage(urlPattern: "gemini.google.com", note: "Gemini"),
    SensitivePage(urlPattern: "perplexity.ai", note: "Perplexity"),
    SensitivePage(urlPattern: "www.mistral.ai", note: "Mistral"),
    SensitivePage(urlPattern: "chat.mistral.ai", note: "Mistral Chat"),
    SensitivePage(urlPattern: "x.ai", note: "xAI (Grok)"),
    SensitivePage(urlPattern: "pi.ai", note: "Pi AI"),
    SensitivePage(urlPattern: "character.ai", note: "Character.AI"),
    SensitivePage(urlPattern: "poe.com", note: "Poe"),
    SensitivePage(urlPattern: "console.anthropic.com", note: "Anthropic Console"),
    SensitivePage(urlPattern: "aistudio.google.com", note: "Google AI Studio"),
  ]
  
  static let `default` = SensitiveWordConfig(
    enabled: true,
    useAutoEncoding: true,
    sensitiveWords: [],
    sensitivePages: defaultAIPages,
    enabledApps: SupportedApp.defaults
  )
}

// MARK: - 脱敏/还原核心逻辑

extension SensitiveWordConfig {
  
  // MARK: 页面判断
  
  func isSensitivePage(url: String?, title: String?) -> Bool {
    guard enabled, !sensitivePages.isEmpty else { return false }
    
    for page in sensitivePages {
      if let url = url, !page.urlPattern.isEmpty {
        if url.contains(page.urlPattern) {
          return true
        }
      }
      if let title = title, let titlePattern = page.titlePattern, !titlePattern.isEmpty {
        if title.contains(titlePattern) {
          return true
        }
      }
    }
    return false
  }
  
  // MARK: 应用判断
  
  func isEnabledApp(_ bundleID: String) -> Bool {
    return enabledApps.contains { $0.bundleID == bundleID && $0.enabled }
  }
  
  // MARK: 脱敏
  
  func maskSensitiveWords(in text: String) -> String {
    var result = text
    for sensitive in sensitiveWords {
      let replacement = getReplacement(for: sensitive)
      result = result.replacingOccurrences(
        of: sensitive.word,
        with: replacement,
        options: [.caseInsensitive, .diacriticInsensitive]
      )
    }
    return result
  }
  
  // MARK: 还原
  
  func restoreSensitiveWords(in text: String) -> String {
    var result = text
    
    // 1. 还原自动编码的词（Base64 格式）
    result = restoreAutoEncodedWords(in: result)
    
    // 2. 还原自定义替换词
    result = restoreCustomReplacementWords(in: result)
    
    return result
  }
  
  // MARK: 获取替换文本
  
  private func getReplacement(for sensitive: SensitiveWord) -> String {
    if let custom = sensitive.replacement, !custom.isEmpty {
      return custom
    }
    if useAutoEncoding {
      return generateAutoEncoding(for: sensitive.word)
    }
    return generateStarMask(for: sensitive.word)
  }
  
  // MARK: 自动编码（可还原）
  
  private func generateAutoEncoding(for word: String) -> String {
    let data = word.data(using: .utf8) ?? Data()
    let base64 = data.base64EncodedString()
    return "\(Self.encodingPrefix)\(base64)\(Self.encodingSuffix)"
  }
  
  private func restoreAutoEncodedWords(in text: String) -> String {
    let pattern = "\(Self.encodingPrefix)[A-Za-z0-9+/=]+\(Self.encodingSuffix)"
    // Use regex to find all Base64 encoded tokens
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return text
    }
    
    let range = NSRange(text.startIndex..., in: text)
    var result = text
    
    let matches = regex.matches(in: text, range: range)
    // Process matches from right to left to preserve indices
    for match in matches.reversed() {
      guard let matchRange = Range(match.range, in: text) else { continue }
      let token = String(text[matchRange])
      
      // Extract Base64 part
      let base64Start = token.index(token.startIndex, offsetBy: Self.encodingPrefix.count)
      let base64End = token.index(token.endIndex, offsetBy: -Self.encodingSuffix.count)
      let base64 = String(token[base64Start..<base64End])
      
      // Decode Base64
      if let data = Data(base64Encoded: base64),
         let decoded = String(data: data, encoding: .utf8) {
        result.replaceSubrange(matchRange, with: decoded)
      }
    }
    
    return result
  }
  
  // MARK: 自定义替换词还原（两阶段避免冲突）
  
  private func restoreCustomReplacementWords(in text: String) -> String {
    var result = text
    
    let sortedWords = sensitiveWords.filter { $0.replacement != nil }
      .sorted { ($0.replacement ?? "").count > ($1.replacement ?? "").count }
    
    var placeholderMap: [String: String] = [:]
    var counter = 0
    
    for sensitive in sortedWords {
      guard let replacement = sensitive.replacement else { continue }
      let placeholder = "__MACCY_TMP_\(counter)__"
      counter += 1
      result = result.replacingOccurrences(
        of: replacement,
        with: placeholder,
        options: [.caseInsensitive, .diacriticInsensitive]
      )
      placeholderMap[placeholder] = sensitive.word
    }
    
    for (placeholder, originalWord) in placeholderMap {
      result = result.replacingOccurrences(of: placeholder, with: originalWord)
    }
    
    return result
  }
  
  // MARK: 星号掩码（不可还原）
  
  private func generateStarMask(for word: String) -> String {
    let length = word.count
    if length <= 2 {
      return String(repeating: "*", count: length)
    }
    let maskLength = min(max(length / 3, 2), 4)
    let mask = String(repeating: "*", count: maskLength)
    let prefix = word.prefix(1)
    let suffix = word.suffix(1)
    return "\(prefix)\(mask)\(suffix)"
  }
}
