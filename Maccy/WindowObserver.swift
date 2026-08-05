import AppKit
import Foundation
import Defaults

// MARK: - 应用页面信息协议

protocol AppPageInfoProvider {
  var bundleID: String { get }
  var appName: String { get }
  func fetchPageInfo() async -> (url: String?, title: String?)?
}

// MARK: - 通用浏览器提供者（基于 AppleScript）

class BrowserPageProvider: AppPageInfoProvider {
  let bundleID: String
  let appName: String
  private let appPath: String
  
  init(bundleID: String, appName: String, appPath: String) {
    self.bundleID = bundleID
    self.appName = appName
    self.appPath = appPath
  }
  
  func fetchPageInfo() async -> (url: String?, title: String?)? {
    let script = """
    tell application "\(appName)"
        if (count of windows) > 0 then
            set tabURL to URL of active tab of front window
            set tabTitle to title of active tab of front window
            return tabURL & "||" & tabTitle
        else
            return "||"
        end if
    end tell
    """
    
    let result = await runAppleScript(script)
    return parseResult(result)
  }
  
  private func runAppleScript(_ script: String) async -> String {
    return await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
          .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        continuation.resume(returning: output)
      }
    }
  }
  
  private func parseResult(_ output: String) -> (url: String?, title: String?)? {
    let components = output.split(separator: "||", maxSplits: 1, omittingEmptySubsequences: false)
    guard components.count == 2 else { return nil }
    
    let url = String(components[0]).isEmpty ? nil : String(components[0])
    let title = String(components[1]).isEmpty ? nil : String(components[1])
    return (url, title)
  }
}

// MARK: - VS Code / Codex 等 Electron 应用提供者

class ElectronAppPageProvider: AppPageInfoProvider {
  let bundleID: String
  let appName: String
  
  init(bundleID: String, appName: String) {
    self.bundleID = bundleID
    self.appName = appName
  }
  
  func fetchPageInfo() async -> (url: String?, title: String?)? {
    // Electron apps may not expose tab info via AppleScript
    // We detect the frontmost window and use accessibility APIs
    let script = """
    tell application "System Events"
        tell process "\(appName)"
            if (count of windows) > 0 then
                set frontWindow to front window
                return name of frontWindow
            end if
        end tell
    end tell
    """
    
    let windowTitle = await runAppleScript(script)
    // For Electron apps, the window title often contains the "page" info
    // We return nil URL but use window title as context
    return (url: nil, title: windowTitle.isEmpty ? nil : windowTitle)
  }
  
  private func runAppleScript(_ script: String) async -> String {
    return await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
          .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        continuation.resume(returning: output)
      }
    }
  }
}

// MARK: - 窗口观察者（支持多应用）

@MainActor
class WindowObserver: ObservableObject {
  static let shared = WindowObserver()
  
  @Published var currentBundleID: String? = nil
  @Published var currentPageURL: String? = nil
  @Published var currentPageTitle: String? = nil
  @Published var isOnSensitivePage: Bool = false
  
  private var frontmostApplicationObserver: NSObjectProtocol?
  private var providers: [String: AppPageInfoProvider] = [:]
  
  private init() {
    setupProviders()
    startObserving()
  }
  
  // MARK: Provider Setup
  
  private func setupProviders() {
    // Browsers with full AppleScript support
    let browserConfigs: [(bundleID: String, name: String, path: String)] = [
      ("com.google.Chrome", "Google Chrome", "/Applications/Google Chrome.app"),
      ("com.microsoft.edgemac", "Microsoft Edge", "/Applications/Microsoft Edge.app"),
      ("com.brave.Browser", "Brave Browser", "/Applications/Brave Browser.app"),
      ("company.thebrowser.Browser", "Arc", "/Applications/Arc.app"),
      ("com.apple.Safari", "Safari", "/Applications/Safari.app"),
    ]
    
    for config in browserConfigs {
      providers[config.bundleID] = BrowserPageProvider(
        bundleID: config.bundleID,
        appName: config.name,
        appPath: config.path
      )
    }
    
    // Electron-based apps
    let electronConfigs: [(bundleID: String, name: String)] = [
      ("com.jetbrains.codex", "Codex"),
      ("com.todesktop.23031353043909097", "Cursor"),
      ("com.microsoft.VSCode", "Code"),
      ("com.googlecode.iterm2", "iTerm2"),
      ("com.figma.Desktop", "Figma"),
    ]
    
    for config in electronConfigs {
      providers[config.bundleID] = ElectronAppPageProvider(
        bundleID: config.bundleID,
        appName: config.name
      )
    }
  }
  
  // MARK: Observation
  
  private func startObserving() {
    frontmostApplicationObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self = self else { return }
      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      self.handleApplicationChange(app)
    }
    
    checkCurrentApplication()
  }
  
  private func handleApplicationChange(_ app: NSRunningApplication?) {
    guard let app = app else {
      currentBundleID = nil
      currentPageURL = nil
      currentPageTitle = nil
      isOnSensitivePage = false
      return
    }
    
    let bundleID = app.bundleIdentifier
    currentBundleID = bundleID
    
    guard let bundleID = bundleID,
          Defaults[.sensitiveWordConfig].isEnabledApp(bundleID) else {
      currentPageURL = nil
      currentPageTitle = nil
      isOnSensitivePage = false
      return
    }
    
    Task {
      await fetchPageInfo(for: bundleID)
    }
  }
  
  private func fetchPageInfo(for bundleID: String) async {
    guard let provider = providers[bundleID] else { return }
    
    if let info = await provider.fetchPageInfo() {
      currentPageURL = info.url
      currentPageTitle = info.title
      
      let config = Defaults[.sensitiveWordConfig]
      isOnSensitivePage = config.isSensitivePage(url: info.url, title: info.title)
    }
  }
  
  private func checkCurrentApplication() {
    if let app = NSWorkspace.shared.frontmostApplication {
      handleApplicationChange(app)
    }
  }
  
  // MARK: Public API
  
  func refreshCurrentPage() async {
    guard let bundleID = currentBundleID else { return }
    await fetchPageInfo(for: bundleID)
  }
  
  var isSensitiveContext: Bool {
    let config = Defaults[.sensitiveWordConfig]
    return isOnSensitivePage && config.enabled
  }
}
