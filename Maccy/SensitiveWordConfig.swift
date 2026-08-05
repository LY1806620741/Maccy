import Foundation
import SwiftUI

struct SensitiveWord: Identifiable, Codable, Hashable {
  var id: UUID = UUID()
  var word: String
  var replacement: String?
  
  init(id: UUID = UUID(), word: String, replacement: String? = nil) {
    self.id = id
    self.word = word
    self.replacement = replacement
  }
}

struct SensitivePage: Identifiable, Codable, Hashable {
  var id: UUID = UUID()
  var urlPattern: String
  var titlePattern: String?
  
  init(id: UUID = UUID(), urlPattern: String, titlePattern: String? = nil) {
    self.id = id
    self.urlPattern = urlPattern
    self.titlePattern = titlePattern
  }
}

struct SensitiveWordConfig: Codable {
  var enabled: Bool = true
  var autoMask: Bool = true
  var sensitiveWords: [SensitiveWord] = []
  var sensitivePages: [SensitivePage] = []
  
  static let `default` = SensitiveWordConfig()
}

extension SensitiveWordConfig {
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
  
  func maskSensitiveWords(in text: String) -> String {
    var result = text
    for sensitive in sensitiveWords {
      let replacement = sensitive.replacement ?? generateAutoMask(for: sensitive.word)
      result = result.replacingOccurrences(of: sensitive.word, with: replacement, options: .caseInsensitive)
    }
    return result
  }
  
  func restoreSensitiveWords(in text: String) -> String {
    var result = text
    for sensitive in sensitiveWords {
      guard let replacement = sensitive.replacement else { continue }
      result = result.replacingOccurrences(of: replacement, with: sensitive.word, options: .caseInsensitive)
    }
    return result
  }
  
  private func generateAutoMask(for word: String) -> String {
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
