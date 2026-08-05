import SwiftUI
import AppKit

// MARK: - 截图生成器

// This script generates a screenshot of the Sensitive Words settings page.
// It can be compiled and run independently:
//   swiftc scripts/generate_screenshot.swift -o scripts/generate_screenshot
//   ./scripts/generate_screenshot

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath + "/sensitive-words-settings.png"

// MARK: - 数据模型（与主项目保持一致）

struct SensitiveWordItem: Identifiable {
    let id = UUID()
    let word: String
    let replacement: String?
}

struct SensitivePageItem: Identifiable {
    let id = UUID()
    let urlPattern: String
    let note: String
}

struct SupportedAppItem: Identifiable {
    let id = String
    let bundleID: String
    let name: String
    let enabled: Bool
    let icon: String
}

// MARK: - 配置预览数据

let previewWords: [SensitiveWordItem] = [
    .init(word: "password", replacement: nil),
    .init(word: "secret_key", replacement: nil),
    .init(word: "api_token", replacement: "[REDACTED]"),
    .init(word: "密码", replacement: nil),
]

let previewApps: [SupportedAppItem] = [
    .init(id: "com.google.Chrome", bundleID: "com.google.Chrome", name: "Google Chrome", enabled: true, icon: "globe"),
    .init(id: "com.microsoft.edgemac", bundleID: "com.microsoft.edgemac", name: "Microsoft Edge", enabled: true, icon: "globe"),
    .init(id: "com.brave.Browser", bundleID: "com.brave.Browser", name: "Brave Browser", enabled: true, icon: "globe"),
    .init(id: "com.jetbrains.codex", bundleID: "com.jetbrains.codex", name: "Codex", enabled: true, icon: "hammer"),
    .init(id: "com.todesktop.23031353043909097", bundleID: "com.todesktop.23031353043909097", name: "Cursor", enabled: true, icon: "cursor"),
    .init(id: "com.microsoft.VSCode", bundleID: "com.microsoft.VSCode", name: "VS Code", enabled: true, icon: "chevron.left.forwardslash.chevron.right"),
]

let previewPages: [SensitivePageItem] = [
    .init(urlPattern: "chat.openai.com", note: "ChatGPT"),
    .init(urlPattern: "claude.ai", note: "Claude AI"),
    .init(urlPattern: "gemini.google.com", note: "Gemini"),
    .init(urlPattern: "perplexity.ai", note: "Perplexity"),
    .init(urlPattern: "x.ai", note: "xAI (Grok)"),
    .init(urlPattern: "character.ai", note: "Character.AI"),
]

// MARK: - 图标映射

func appIcon(for bundleID: String) -> String {
    switch bundleID {
    case "com.google.Chrome": return "globe"
    case "com.microsoft.edgemac": return "globe"
    case "com.brave.Browser": return "globe"
    case "company.thebrowser.Browser": return "globe"
    case "com.apple.Safari": return "safari"
    case "com.jetbrains.codex": return "hammer"
    case "com.todesktop.23031353043909097": return "cursor"
    case "com.microsoft.VSCode": return "chevron.left.forwardslash.chevron.right"
    case "com.googlecode.iterm2": return "terminal"
    case "com.figma.Desktop": return "paintpalette"
    default: return "app"
    }
}

// MARK: - 主视图

struct ScreenshotView: View {
    var body: some View {
        ZStack {
            // 背景
            Color(NSColor.windowBackgroundColor)
            
            VStack(alignment: .leading, spacing: 0) {
                // 标题栏
                headerBar
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 启用开关
                        enableSection
                        
                        // 编码模式
                        encodingSection
                        
                        // 应用列表
                        appsSection
                        
                        // 敏感词列表
                        wordsSection
                        
                        // 敏感页面
                        pagesSection
                        
                        // 底部说明
                        footerSection
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 520, height: 780)
    }
    
    private var headerBar: some View {
        HStack {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 18))
                .foregroundStyle(.blue)
            Text("敏感词保护")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Text("v2.7.0")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Divider(), alignment: .bottom
        )
    }
    
    private var enableSection: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("启用敏感词保护")
                .font(.body)
            Spacer()
            Toggle("", isOn: .constant(true))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
    
    private var encodingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("脱敏方式")
                .font(.headline)
            
            HStack(spacing: 20) {
                radioOption(isSelected: true, icon: "lock.fill", title: "自动编码", subtitle: "Base64 编码，可完全还原")
                radioOption(isSelected: false, icon: "eye.slash.fill", title: "星号掩码", subtitle: "p**d 格式，不可还原")
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func radioOption(isSelected: Bool, icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                .foregroundStyle(isSelected ? .blue : .secondary)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("监控应用")
                    .font(.headline)
                Spacer()
                Text("已启用 \(previewApps.filter { $0.enabled }.count)/\(previewApps.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 4) {
                ForEach(previewApps) { app in
                    HStack {
                        Image(systemName: appIcon(for: app.bundleID))
                            .foregroundStyle(.blue)
                            .frame(width: 18)
                        Text(app.name)
                            .font(.subheadline)
                        Spacer()
                        Text(app.bundleID)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Toggle("", isOn: .constant(app.enabled))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .frame(width: 36)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
    
    private var wordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("敏感词列表")
                    .font(.headline)
                Spacer()
                Text("\(previewWords.count) 个词")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 4) {
                ForEach(previewWords) { word in
                    HStack(spacing: 8) {
                        Text(word.word)
                            .font(.system(.subheadline, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 10))
                        
                        if let replacement = word.replacement {
                            Text(replacement)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            Text("__MACCY_B64_\(encode(word.word))__")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
    
    private var pagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("敏感页面")
                    .font(.headline)
                Spacer()
                Button(action: {}) {
                    Label("加载 AI 默认", systemImage: "sparkles")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.blue)
            }
            
            VStack(spacing: 4) {
                ForEach(previewPages) { page in
                    HStack {
                        Image(systemName: "globe")
                            .foregroundStyle(.blue)
                            .font(.system(size: 12))
                        Text(page.urlPattern)
                            .font(.system(.subheadline, design: .monospaced))
                        Spacer()
                        Text(page.note)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
    
    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("""
            自动编码模式说明：
            敏感词将被编码为 Base64 格式（__MACCY_B64_<编码>__），
            粘贴到敏感页面时自动脱敏，复制回来时自动还原。
            """)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func encode(_ string: String) -> String {
        Data(string.utf8).base64EncodedString()
    }
}

// MARK: - 渲染并保存

let view = ScreenshotView()
    .environment(\.locale, .init(identifier: "zh-Hans"))
    .frame(width: 520, height: 780)

let renderer = ImageRenderer(content: view)
renderer.scale = 2.0
renderer.proposedSize = ProposedViewSize(width: 520, height: 780)

let outputURL = URL(fileURLWithPath: outputPath)

// MARK: 渲染策略：多重回退

func savePNG(_ data: Data, to url: URL) throws {
    try data.write(to: url, options: .atomic)
}

func renderWithImageRenderer() -> Bool {
    let cgImage = renderer.render()
    guard let cgImage = cgImage else { return false }
    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return false }
    try? savePNG(pngData, to: outputURL)
    return FileManager.default.fileExists(atPath: outputPath)
}

func renderWithHostingView() -> Bool {
    let rect = NSRect(x: 0, y: 0, width: 520, height: 780)
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = rect
    hostingView.wantsLayer = true
    guard let bitmapRep = hostingView.bitmapImageRepForCaching(in: rect) else { return false }
    hostingView.cacheDisplay(in: rect, from: bitmapRep)
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return false }
    try? savePNG(pngData, to: outputURL)
    return FileManager.default.fileExists(atPath: outputPath)
}

func renderWithSnapshot() -> Bool {
    let rect = NSRect(x: 0, y: 0, width: 520, height: 780)
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = rect
    let snapshot = hostingView.snapshot
    guard let tiffData = snapshot.tiffRepresentation else { return false }
    guard let bitmapRep = NSBitmapImageRep(data: tiffData) else { return false }
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return false }
    try? savePNG(pngData, to: outputURL)
    return FileManager.default.fileExists(atPath: outputPath)
}

var success = false
var method = ""

// 策略 1: ImageRenderer (macOS 14+, 最可靠)
if renderWithImageRenderer() {
    success = true
    method = "ImageRenderer"
}
// 策略 2: NSHostingView + bitmapImageRep
else if renderWithHostingView() {
    success = true
    method = "NSHostingView"
}
// 策略 3: NSHostingView + snapshot
else if renderWithSnapshot() {
    success = true
    method = "NSView.snapshot"
}

if success {
    print("✅ Screenshot saved to: \(outputPath)")
    print("   Render method: \(method)")
    print("   Size: 520x780 @ 2x scale (1040x1560 pixels)")
    let attrs = try? FileManager.default.attributesOfItem(atPath: outputPath)
    if let size = attrs?[.size] as? Int {
        print("   File size: \(size / 1024)KB")
    }
} else {
    fflush(stderr)
    fatalError("❌ Failed to generate screenshot with all methods")
}
