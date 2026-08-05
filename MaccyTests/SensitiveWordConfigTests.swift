import XCTest
@testable import Maccy

final class SensitiveWordConfigTests: XCTestCase {
  
  // MARK: - Auto Encoding (Base64) Tests
  
  func testAutoEncodingMaskAndRestore() {
    var config = SensitiveWordConfig()
    config.enabled = true
    config.useAutoEncoding = true
    config.sensitiveWords = [SensitiveWord(word: "password")]
    
    let original = "My password is secret"
    let masked = config.maskSensitiveWords(in: original)
    
    // Should use Base64 encoding format
    XCTAssertTrue(masked.contains("__MACCY_B64_"), "Should use Base64 encoding prefix")
    XCTAssertTrue(masked.contains("__"), "Should have encoding suffix")
    XCTAssertNotEqual(masked, original, "Should mask the word")
    
    // Should be restorable
    let restored = config.restoreSensitiveWords(in: masked)
    XCTAssertEqual(restored, original, "Should restore original text")
  }
  
  func testAutoEncodingMultipleWords() {
    var config = SensitiveWordConfig()
    config.enabled = true
    config.useAutoEncoding = true
    config.sensitiveWords = [
      SensitiveWord(word: "password"),
      SensitiveWord(word: "secret_key")
    ]
    
    let original = "My password and secret_key are safe"
    let masked = config.maskSensitiveWords(in: original)
    let restored = config.restoreSensitiveWords(in: masked)
    
    XCTAssertEqual(restored, original, "Multiple auto-encoded words should be fully restorable")
  }
  
  func testAutoEncodingWithChinese() {
    var config = SensitiveWordConfig()
    config.enabled = true
    config.useAutoEncoding = true
    config.sensitiveWords = [SensitiveWord(word: "密码")]
    
    let original = "我的密码很安全"
    let masked = config.maskSensitiveWords(in: original)
    let restored = config.restoreSensitiveWords(in: masked)
    
    XCTAssertEqual(restored, original, "Chinese characters should be fully restorable")
  }
  
  func testAutoEncodingBase64Format() {
    var config = SensitiveWordConfig()
    config.enabled = true
    config.useAutoEncoding = true
    config.sensitiveWords = [SensitiveWord(word: "test")]
    
    let masked = config.maskSensitiveWords(in: "test")
    // test → Base64 → dGVzdA==
    XCTAssertEqual(masked, "__MACCY_B64_dGVzdA==__")
  }
  
  func testAutoEncodingCaseInsensitive() {
    var config = SensitiveWordConfig()
    config.enabled = true
    config.useAutoEncoding = true
    config.sensitiveWords = [SensitiveWord(word: "Password")]
    
    let masked = config.maskSensitiveWords(in: "PASSWORD should be masked")
    let restored = config.restoreSensitiveWords(in: masked)
    
    // The masked version will encode "PASSWORD" (uppercase)
    // But restore will decode back to whatever was encoded
    XCTAssertTrue(masked.contains("__MACCY_B64_"), "Should mask case-insensitively")
    XCTAssertTrue(restored.contains("PASSWORD") || restored.contains("Password"), "Should restore the original case")
  }
  
  // MARK: - Star Mask Tests (not restorable)
  
  func testStarMaskNotRestorable() {
    var config = SensitiveWordConfig()
    config.enabled = true
    config.useAutoEncoding = false  // Star mask mode
    config.sensitiveWords = [SensitiveWord(word: "password")]
    
    let original = "My password is secret"
    let masked = config.maskSensitiveWords(in: original)
    
    // Should use star mask
    XCTAssertTrue(masked.contains("*"), "Should use stars")
    XCTAssertNotEqual(masked, original, "Should mask the word")
    
    // Cannot restore star masks
    let restored = config.restoreSensitiveWords(in: masked)
    XCTAssertNotEqual(restored, original, "Star masks cannot be restored")
  }
  
  // MARK: - Custom Replacement Tests
  
  func testCustomReplacementRoundTrip() {
    var config = SensitiveWordConfig()
    config.enabled = true
    config.useAutoEncoding = true
    config.sensitiveWords = [
      SensitiveWord(word: "password", replacement: "[REDACTED]"),
      SensitiveWord(word: "secret", replacement: "[HIDDEN]")
    ]
    
    let original = "My password and secret are safe"
    let masked = config.maskSensitiveWords(in: original)
    let restored = config.restoreSensitiveWords(in: masked)
    
    XCTAssertEqual(masked, "My [REDACTED] and [HIDDEN] are safe")
    XCTAssertEqual(restored, original, "Custom replacements should be restorable")
  }
  
  // MARK: - Mixed Mode Tests
  
  func testMixedAutoAndCustom() {
    var config = SensitiveWordConfig()
    config.enabled = true
    config.useAutoEncoding = true
    config.sensitiveWords = [
      SensitiveWord(word: "password", replacement: "[REDACTED]"),  // Custom
      SensitiveWord(word: "secret_key")  // Auto encoding
    ]
    
    let original = "My password and secret_key are safe"
    let masked = config.maskSensitiveWords(in: original)
    let restored = config.restoreSensitiveWords(in: masked)
    
    XCTAssertEqual(masked, "My [REDACTED] and __MACCY_B64_c2VjcmV0X2tleQ==__ are safe")
    XCTAssertEqual(restored, original, "Mixed mode should be fully restorable")
  }
  
  // MARK: - Sensitive Page Tests
  
  func testDefaultAIPagesExist() {
    XCTAssertTrue(SensitiveWordConfig.defaultAIPages.count > 0, "Default AI pages should exist")
    
    let urls = SensitiveWordConfig.defaultAIPages.map { $0.urlPattern }
    XCTAssertTrue(urls.contains("chat.openai.com"), "Should include ChatGPT")
    XCTAssertTrue(urls.contains("claude.ai"), "Should include Claude")
    XCTAssertTrue(urls.contains("gemini.google.com"), "Should include Gemini")
    XCTAssertTrue(urls.contains("perplexity.ai"), "Should include Perplexity")
  }
  
  func testDefaultConfigHasAIPages() {
    let config = SensitiveWordConfig.default
    XCTAssertTrue(config.sensitivePages.count > 0, "Default config should include AI pages")
  }
  
  func testIsSensitivePageWithDefaultConfig() {
    let config = SensitiveWordConfig.default
    
    XCTAssertTrue(config.isSensitivePage(url: "https://chat.openai.com/chat", title: "ChatGPT"))
    XCTAssertTrue(config.isSensitivePage(url: "https://claude.ai/chat", title: "Claude"))
    XCTAssertTrue(config.isSensitivePage(url: "https://stackoverflow.com/questions/123", title: "Stack Overflow") == false)
  }
  
  // MARK: - App Detection Tests
  
  func testSupportedAppsExist() {
    XCTAssertTrue(SupportedApp.defaults.count > 0, "Supported apps should exist")
    
    let bundleIDs = SupportedApp.defaults.map { $0.bundleID }
    XCTAssertTrue(bundleIDs.contains("com.google.Chrome"), "Should include Chrome")
    XCTAssertTrue(bundleIDs.contains("com.jetbrains.codex"), "Should include Codex")
    XCTAssertTrue(bundleIDs.contains("com.todesktop.23031353043909097"), "Should include Cursor")
    XCTAssertTrue(bundleIDs.contains("com.microsoft.VSCode"), "Should include VS Code")
  }
  
  func testIsEnabledApp() {
    let config = SensitiveWordConfig.default
    
    XCTAssertTrue(config.isEnabledApp("com.google.Chrome"), "Chrome should be enabled by default")
    XCTAssertTrue(config.isEnabledApp("com.jetbrains.codex"), "Codex should be enabled by default")
    XCTAssertTrue(config.isEnabledApp("com.todesktop.23031353043909097"), "Cursor should be enabled by default")
    XCTAssertFalse(config.isEnabledApp("com.apple.Safari"), "Safari should be disabled by default")
    XCTAssertFalse(config.isEnabledApp("com.unknown.app"), "Unknown app should not be enabled")
  }
  
  func testDisabledAppDetection() {
    var config = SensitiveWordConfig.default
    config.enabledApps = config.enabledApps.map { app in
      var a = app
      if a.bundleID == "com.google.Chrome" { a.enabled = false }
      return a
    }
    
    XCTAssertFalse(config.isEnabledApp("com.google.Chrome"), "Disabled Chrome should not be detected")
    XCTAssertTrue(config.isEnabledApp("com.jetbrains.codex"), "Codex should still be enabled")
  }
  
  // MARK: - Edge Cases
  
  func testEmptyConfig() {
    let config = SensitiveWordConfig()
    XCTAssertEqual(config.maskSensitiveWords(in: "test"), "test", "Empty config should not mask")
    XCTAssertEqual(config.restoreSensitiveWords(in: "test"), "test", "Empty config should not restore")
  }
  
  func testDisabledConfig() {
    var config = SensitiveWordConfig()
    config.enabled = false
    config.sensitiveWords = [SensitiveWord(word: "password")]
    
    // isSensitivePage checks enabled
    XCTAssertFalse(config.isSensitivePage(url: "https://example.com", title: "password page"))
    
    // maskSensitiveWords does NOT check enabled (works independently)
    let masked = config.maskSensitiveWords(in: "password")
    XCTAssertNotEqual(masked, "password", "Masking should work even when disabled - it's the page detection that's disabled")
  }
  
  func testEncodingTokensDontConflict() {
    var config = SensitiveWordConfig()
    config.enabled = true
    config.useAutoEncoding = true
    config.sensitiveWords = [SensitiveWord(word: "test")]
    
    // The encoding token format should not appear in normal text
    let masked = config.maskSensitiveWords(in: "This is a test with normal content __MACCY_B64_ prefix")
    // The word "test" should be encoded, and any existing token-like text should remain
    let restored = config.restoreSensitiveWords(in: masked)
    XCTAssertTrue(restored.contains("__MACCY_B64_ prefix"), "Non-conflicting tokens should be preserved")
  }
  
  func testSpecialCharacters() {
    var config = SensitiveWordConfig()
    config.enabled = true
    config.useAutoEncoding = true
    config.sensitiveWords = [SensitiveWord(word: "user@domain.com")]
    
    let original = "Email: user@domain.com for info"
    let masked = config.maskSensitiveWords(in: original)
    let restored = config.restoreSensitiveWords(in: masked)
    
    XCTAssertEqual(restored, original, "Special characters should be preserved through encoding")
  }
  
  // MARK: - Full Round Trip
  
  func testFullRoundTripAutoEncoding() {
    var config = SensitiveWordConfig()
    config.enabled = true
    config.useAutoEncoding = true
    config.sensitiveWords = [
      SensitiveWord(word: "password"),
      SensitiveWord(word: "secret_key"),
      SensitiveWord(word: "api_token_123"),
      SensitiveWord(word: "密码"),
    ]
    
    let original = """
    用户密码: my_password_value
    API: secret_key_xyz
    Token: api_token_123_abc
    中文密码保护
    """
    
    let masked = config.maskSensitiveWords(in: original)
    let restored = config.restoreSensitiveWords(in: masked)
    
    XCTAssertEqual(restored, original, "Full round trip should preserve original text exactly")
  }
  
  func testFullRoundTripWithCustomReplacements() {
    var config = SensitiveWordConfig()
    config.enabled = true
    config.useAutoEncoding = false
    config.sensitiveWords = [
      SensitiveWord(word: "password", replacement: "<PASSWORD>"),
      SensitiveWord(word: "secret", replacement: "<SECRET>"),
    ]
    
    let original = "My password and secret are both secure"
    let masked = config.maskSensitiveWords(in: original)
    let restored = config.restoreSensitiveWords(in: masked)
    
    XCTAssertEqual(masked, "My <PASSWORD> and <SECRET> are both secure")
    XCTAssertEqual(restored, original, "Custom replacement round trip should work")
  }
}
