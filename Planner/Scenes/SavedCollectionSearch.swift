#if os(iOS)
  import SwiftUI

  /// Isolate iPhone Map search from the system's minimized-toolbar transition.
  struct SavedCollectionSearch: ViewModifier {
    @Binding var text: String
    let placement: SearchFieldPlacement
    let prompt: String
    let usesMap: Bool
    @State private var isPresented = false
    @State private var query = ""
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
      if usesMap && UIDevice.current.userInterfaceIdiom == .phone {
        content
          .toolbar {
            ToolbarItem(placement: .primaryAction) {
              Button("Search", systemImage: searchSymbol) {
                query = text
                isPresented = true
              }
              .labelStyle(.iconOnly)
              .accessibilityValue(text)
            }
          }
          .sheet(
            isPresented: $isPresented, onDismiss: { text = query },
            content: { searchEditor })
      } else {
        content
          .searchable(text: $text, placement: placement, prompt: Text(prompt))
          .searchToolbarBehavior(usesMap ? .minimize : .automatic)
      }
    }

    private var searchSymbol: String {
      if text.isEmpty { return "magnifyingglass" }
      return "magnifyingglass.circle.fill"
    }

    private var searchEditor: some View {
      NavigationStack {
        Form {
          TextField(prompt, text: $query)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isFocused)
            .accessibilityIdentifier("saved.map.search.text")
          if !query.isEmpty {
            Button("Clear search", systemImage: "xmark.circle") { query = "" }
              .accessibilityIdentifier("saved.map.search.clear")
          }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { isPresented = false }
              .accessibilityIdentifier("saved.map.search.done")
          }
        }
        .task { isFocused = true }
      }
      .presentationDetents([.medium, .large])
    }
  }
#endif
