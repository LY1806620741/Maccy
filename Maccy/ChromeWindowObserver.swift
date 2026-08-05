import AppKit
import Foundation
import Defaults

@MainActor
class ChromeWindowObserver {
  static let shared = ChromeWindowObserver()
  
  private var frontmostApplicationObserver: NSObjectProtocol?
  private var currentPageInfo: (url: String?, title: String?)?
  
  var onSensitivePageChange: ((Bool) -> Void)?
  
  private init() {
    startObserving()
  }
  
  func startObserving() {
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
  
  func stopObserving() {
    if let observer = frontmostApplicationObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
      frontmostApplicationObserver = nil
    }
  }
  
  var isChromeActive: Bool {
    guard let app = NSWorkspace.shared.frontmostApplication else { return false }
    return app.bundleIdentifier == "com.google.Chrome"
  }
  
  var currentURL: String? {
    return currentPageInfo?.url
  }
  
  var currentTitle: String? {
    return currentPageInfo?.title
  }
  
  var isOnSensitivePage: Bool {
    let config = Defaults[.sensitiveWordConfig]
    return config.isSensitivePage(url: currentURL, title: currentTitle)
  }
  
  private func handleApplicationChange(_ app: NSRunningApplication?) {
    guard let app = app else {
      currentPageInfo = nil
      onSensitivePageChange?(false)
      return
    }
    
    if app.bundleIdentifier == "com.google.Chrome" {
      Task {
        await fetchChromePageInfo()
      }
    } else {
      currentPageInfo = nil
      onSensitivePageChange?(false)
    }
  }
  
  private func checkCurrentApplication() {
    if let app = NSWorkspace.shared.frontmostApplication {
      handleApplicationChange(app)
    }
  }
  
  private func fetchChromePageInfo() async {
    let semaphore = DispatchSemaphore(value: 0)
    var result: (url: String?, title: String?) = (nil, nil)
    
    let script = """
    tell application "Google Chrome"
        if (count of windows) > 0 then
            set tabURL to URL of active tab of front window
            set tabTitle to title of active tab of front window
            return tabURL & "|" & tabTitle
        else
            return "|"
        end if
    end tell
    """
    
    DispatchQueue.global(qos: .userInitiated).async {
      let task = Process()
      task.launchPath = "/usr/bin/osascript"
      task.arguments = ["-e", script]
      
      let pipe = Pipe()
      task.standardOutput = pipe
      task.standardError = Pipe()
      
      task.launch()
      
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      task.waitUntilExit()
      
      if task.terminationStatus == 0,
         let output = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) {
        let components = output.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        if components.count == 2 {
          result.url = String(components[0]).isEmpty ? nil : String(components[0])
          result.title = String(components[1]).isEmpty ? nil : String(components[1])
        }
      }
      
      semaphore.signal()
    }
    
    semaphore.wait()
    
    await MainActor.run {
      currentPageInfo = result
      let config = Defaults[.sensitiveWordConfig]
      onSensitivePageChange?(config.isSensitivePage(url: result.url, title: result.title))
    }
  }
  
  func refreshCurrentPageInfo() async {
    if isChromeActive {
      await fetchChromePageInfo()
    }
  }
}
