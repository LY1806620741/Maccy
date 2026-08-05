import SwiftUI
import Defaults

struct SensitiveWordsSettingsPane: View {
  @Default(.sensitiveWordConfig) private var config
  
  var body: some View {
    Settings.Container(contentWidth: 450) {
      Settings.Section(title: "") {
        Defaults.Toggle(key: .sensitiveWordConfig) {
          Text(LocalizedStringKey("Enabled", tableName: "SensitiveWordsSettings"))
        }
        .fixedSize()
      }
      
      Settings.Section(title: LocalizedStringKey("AutoMaskSection", tableName: "SensitiveWordsSettings")) {
        Toggle(isOn: $config.autoMask) {
          Text(LocalizedStringKey("AutoMask", tableName: "SensitiveWordsSettings"))
        }
        .disabled(!config.enabled)
        .fixedSize()
      }
      
      Settings.Section(title: LocalizedStringKey("SensitiveWordsSection", tableName: "SensitiveWordsSettings")) {
        SensitiveWordListView(config: $config)
          .disabled(!config.enabled)
          .frame(minHeight: 150)
      }
      
      Settings.Section(title: LocalizedStringKey("SensitivePagesSection", tableName: "SensitiveWordsSettings")) {
        SensitivePageListView(config: $config)
          .disabled(!config.enabled)
          .frame(minHeight: 150)
      }
      
      Settings.Section(title: "") {
        Text(LocalizedStringKey("Description", tableName: "SensitiveWordsSettings"))
          .fixedSize(horizontal: false, vertical: true)
          .foregroundStyle(.gray)
          .controlSize(.small)
      }
    }
  }
}

struct SensitiveWordListView: View {
  @Binding var config: SensitiveWordConfig
  @State private var newWord: String = ""
  @State private var newReplacement: String = ""
  
  var body: some View {
    VStack(alignment: .leading) {
      List {
        ForEach($config.sensitiveWords) { $sensitive in
          HStack(spacing: 10) {
            TextField(LocalizedStringKey("SensitiveWord", tableName: "SensitiveWordsSettings"), text: $sensitive.word)
              .textFieldStyle(.roundedBorder)
            
            TextField(LocalizedStringKey("ReplacementOptional", tableName: "SensitiveWordsSettings"), text: Binding(
              get: { sensitive.replacement ?? "" },
              set: { sensitive.replacement = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            Button(action: {
              removeWord(sensitive.id)
            }) {
              Image(systemName: "trash")
                .foregroundColor(.red)
            }
            .buttonStyle(.plain)
          }
          .padding(.vertical, 2)
        }
      }
      .listStyle(.plain)
      
      HStack {
        TextField(LocalizedStringKey("AddSensitiveWord", tableName: "SensitiveWordsSettings"), text: $newWord)
          .textFieldStyle(.roundedBorder)
        
        TextField(LocalizedStringKey("ReplacementOptional", tableName: "SensitiveWordsSettings"), text: $newReplacement)
          .textFieldStyle(.roundedBorder)
        
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
    config.sensitiveWords.append(SensitiveWord(word: word, replacement: newReplacement.isEmpty ? nil : newReplacement))
    newWord = ""
    newReplacement = ""
  }
  
  private func removeWord(_ id: UUID) {
    config.sensitiveWords.removeAll { $0.id == id }
  }
}

struct SensitivePageListView: View {
  @Binding var config: SensitiveWordConfig
  @State private var newURLPattern: String = ""
  @State private var newTitlePattern: String = ""
  
  var body: some View {
    VStack(alignment: .leading) {
      List {
        ForEach($config.sensitivePages) { $page in
          HStack(spacing: 10) {
            TextField(LocalizedStringKey("URLPattern", tableName: "SensitiveWordsSettings"), text: $page.urlPattern)
              .textFieldStyle(.roundedBorder)
            
            TextField(LocalizedStringKey("TitlePatternOptional", tableName: "SensitiveWordsSettings"), text: Binding(
              get: { page.titlePattern ?? "" },
              set: { page.titlePattern = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            Button(action: {
              removePage(page.id)
            }) {
              Image(systemName: "trash")
                .foregroundColor(.red)
            }
            .buttonStyle(.plain)
          }
          .padding(.vertical, 2)
        }
      }
      .listStyle(.plain)
      
      HStack {
        TextField(LocalizedStringKey("AddURLPattern", tableName: "SensitiveWordsSettings"), text: $newURLPattern)
          .textFieldStyle(.roundedBorder)
        
        TextField(LocalizedStringKey("TitlePatternOptional", tableName: "SensitiveWordsSettings"), text: $newTitlePattern)
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
    config.sensitivePages.append(SensitivePage(urlPattern: urlPattern, titlePattern: newTitlePattern.isEmpty ? nil : newTitlePattern))
    newURLPattern = ""
    newTitlePattern = ""
  }
  
  private func removePage(_ id: UUID) {
    config.sensitivePages.removeAll { $0.id == id }
  }
}

#Preview {
  SensitiveWordsSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
