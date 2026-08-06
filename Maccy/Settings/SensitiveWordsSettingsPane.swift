import SwiftUI
import Defaults
import Settings

struct SensitiveWordsSettingsPane: View {
  @Default(.sensitiveWordConfig) private var config
  
  var body: some View {
    Settings.Container(contentWidth: 480) {
      Settings.Section(title: "") {
        Toggle(isOn: $config.enabled) {
          Text("Enabled", tableName: "SensitiveWordsSettings")
        }
        .toggleStyle(.switch)
        .fixedSize()
      }
      
      Settings.Section(title: NSLocalizedString("EncodingSection", tableName: "SensitiveWordsSettings", comment: "")) {
        encodingPicker
          .disabled(!config.enabled)
      }
      
      Settings.Section(title: NSLocalizedString("AppsSection", tableName: "SensitiveWordsSettings", comment: "")) {
        AppListView(config: $config)
          .disabled(!config.enabled)
          .frame(minHeight: 100)
      }
      
      Settings.Section(title: NSLocalizedString("SensitiveWordsSection", tableName: "SensitiveWordsSettings", comment: "")) {
        SensitiveWordListView(config: $config)
          .disabled(!config.enabled)
          .frame(minHeight: 120)
      }
      
      Settings.Section(title: NSLocalizedString("SensitivePagesSection", tableName: "SensitiveWordsSettings", comment: "")) {
        SensitivePageListView(config: $config)
          .disabled(!config.enabled)
          .frame(minHeight: 120)
      }
      
      Settings.Section(title: "") {
        Text(config.useAutoEncoding
             ? NSLocalizedString("EncodingAutoDescription", tableName: "SensitiveWordsSettings", comment: "")
             : NSLocalizedString("EncodingStarDescription", tableName: "SensitiveWordsSettings", comment: ""))
          .fixedSize(horizontal: false, vertical: true)
          .foregroundStyle(.gray)
          .controlSize(.small)
        
        if config.useAutoEncoding {
          Text("EncodingExample", tableName: "SensitiveWordsSettings")
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(.gray)
            .controlSize(.small)
            .font(.system(.caption, design: .monospaced))
        }
      }
    }
  }
  
  private var encodingPicker: some View {
    Picker("", selection: $config.useAutoEncoding) {
      Text("AutoEncoding", tableName: "SensitiveWordsSettings").tag(true)
      Text("StarMask", tableName: "SensitiveWordsSettings").tag(false)
    }
    .pickerStyle(.radioGroup)
    .labelsHidden()
  }
}

// MARK: - App List View

struct AppListView: View {
  @Binding var config: SensitiveWordConfig
  
  var body: some View {
    VStack(alignment: .leading) {
      List {
        ForEach($config.enabledApps) { $app in
          HStack {
            Toggle(isOn: $app.enabled) {
              HStack(spacing: 8) {
                Image(systemName: appIcon(for: app.bundleID))
                  .foregroundStyle(.blue)
                Text(app.name)
                  .font(.body)
              }
            }
            .toggleStyle(.switch)
            
            Spacer()
            
            Text(app.bundleID)
              .font(.caption)
              .foregroundStyle(.gray)
          }
          .padding(.vertical, 2)
        }
      }
      .listStyle(.plain)
      .frame(minHeight: 80)
    }
  }
  
  private func appIcon(for bundleID: String) -> String {
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
}

// MARK: - Sensitive Word List View

struct SensitiveWordListView: View {
  @Binding var config: SensitiveWordConfig
  @State private var newWord: String = ""
  @State private var newReplacement: String = ""
  
  var body: some View {
    VStack(alignment: .leading) {
      List {
        ForEach($config.sensitiveWords) { $sensitive in
          HStack(spacing: 10) {
            TextField("SensitiveWord", tableName: "SensitiveWordsSettings", text: $sensitive.word)
              .textFieldStyle(.roundedBorder)
            
            TextField("ReplacementOptional", tableName: "SensitiveWordsSettings", text: Binding(
              get: { sensitive.replacement ?? "" },
              set: { sensitive.replacement = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .disabled(!config.useAutoEncoding)
            .help(config.useAutoEncoding
                  ? NSLocalizedString("ReplacementHelpAuto", tableName: "SensitiveWordsSettings", comment: "")
                  : NSLocalizedString("ReplacementHelpStar", tableName: "SensitiveWordsSettings", comment: ""))
            
            Button(action: {
              removeWord(sensitive.id)
            }) {
              Image(systemName: "trash")
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
          }
          .padding(.vertical, 2)
        }
      }
      .listStyle(.plain)
      
      HStack {
        TextField("AddSensitiveWord", tableName: "SensitiveWordsSettings", text: $newWord)
          .textFieldStyle(.roundedBorder)
        
        TextField(config.useAutoEncoding
                  ? "ReplacementOptional"
                  : "ReplacementRequired",
                  tableName: "SensitiveWordsSettings",
                  text: $newReplacement)
          .textFieldStyle(.roundedBorder)
          .disabled(!config.useAutoEncoding)
        
        Button(action: addWord) {
          Image(systemName: "plus.circle.fill")
            .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
        .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
  }
  
  private func addWord() {
    let word = newWord.trimmingCharacters(in: .whitespaces)
    guard !word.isEmpty else { return }
    let replacement = config.useAutoEncoding
      ? (newReplacement.isEmpty ? nil : newReplacement)
      : newReplacement
    config.sensitiveWords.append(SensitiveWord(word: word, replacement: replacement))
    newWord = ""
    newReplacement = ""
  }
  
  private func removeWord(_ id: UUID) {
    config.sensitiveWords.removeAll { $0.id == id }
  }
}

// MARK: - Sensitive Page List View

struct SensitivePageListView: View {
  @Binding var config: SensitiveWordConfig
  @State private var newURLPattern: String = ""
  @State private var newTitlePattern: String = ""
  
  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Button(action: loadDefaultAIPages) {
          Label("LoadAIDefaults", tableName: "SensitiveWordsSettings",
                systemImage: "sparkles")
        }
        .controlSize(.small)
        .buttonStyle(.borderless)
        Spacer()
        Button(action: clearAllPages) {
          Text("ClearAll", tableName: "SensitiveWordsSettings")
        }
        .controlSize(.small)
        .buttonStyle(.borderless)
        .foregroundStyle(.red)
      }
      
      List {
        ForEach($config.sensitivePages) { $page in
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
              TextField("URLPattern", tableName: "SensitiveWordsSettings", text: $page.urlPattern)
                .textFieldStyle(.roundedBorder)
              
              Button(action: {
                removePage(page.id)
              }) {
                Image(systemName: "trash")
                  .foregroundColor(.red)
              }
              .buttonStyle(.plain)
            }
            
            HStack(spacing: 10) {
              TextField("TitlePatternOptional", tableName: "SensitiveWordsSettings", text: Binding(
                get: { page.titlePattern ?? "" },
                set: { page.titlePattern = $0.isEmpty ? nil : $0 }
              ))
              .textFieldStyle(.roundedBorder)
              
              TextField("NoteOptional", tableName: "SensitiveWordsSettings", text: Binding(
                get: { page.note ?? "" },
                set: { page.note = $0.isEmpty ? nil : $0 }
              ))
              .textFieldStyle(.roundedBorder)
            }
            
            if let note = page.note, !note.isEmpty {
              Text(note)
                .font(.caption)
                .foregroundStyle(.blue)
            }
          }
          .padding(.vertical, 4)
        }
      }
      .listStyle(.plain)
      
      HStack {
        TextField("AddURLPattern", tableName: "SensitiveWordsSettings", text: $newURLPattern)
          .textFieldStyle(.roundedBorder)
        
        TextField("TitlePatternOptional", tableName: "SensitiveWordsSettings", text: $newTitlePattern)
          .textFieldStyle(.roundedBorder)
        
        Button(action: addPage) {
          Image(systemName: "plus.circle.fill")
            .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
        .disabled(newURLPattern.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
  }
  
  private func addPage() {
    let urlPattern = newURLPattern.trimmingCharacters(in: .whitespaces)
    guard !urlPattern.isEmpty else { return }
    config.sensitivePages.append(SensitivePage(
      urlPattern: urlPattern,
      titlePattern: newTitlePattern.isEmpty ? nil : newTitlePattern
    ))
    newURLPattern = ""
    newTitlePattern = ""
  }
  
  private func removePage(_ id: UUID) {
    config.sensitivePages.removeAll { $0.id == id }
  }
  
  private func loadDefaultAIPages() {
    for page in SensitiveWordConfig.defaultAIPages {
      if !config.sensitivePages.contains(where: { $0.urlPattern == page.urlPattern }) {
        config.sensitivePages.append(page)
      }
    }
  }
  
  private func clearAllPages() {
    config.sensitivePages.removeAll()
  }
}

#Preview {
  SensitiveWordsSettingsPane()
    .environment(\.locale, .init(identifier: "zh-Hans"))
}
