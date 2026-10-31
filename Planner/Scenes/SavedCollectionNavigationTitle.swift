#if os(iOS)
  import SwiftUI

  /// Short phone layouts otherwise recenter native large titles during rotation.
  struct SavedCollectionNavigationTitle: ViewModifier {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let title: String

    private var showsToolbarTitle: Bool {
      UIDevice.current.userInterfaceIdiom == .phone && verticalSizeClass == .compact
    }

    func body(content: Content) -> some View {
      content
        .navigationTitle(showsToolbarTitle ? "" : title)
        .toolbarTitleDisplayMode(
          UIDevice.current.userInterfaceIdiom == .phone ? .inlineLarge : .inline
        )
        .toolbar {
          if showsToolbarTitle {
            ToolbarItem(placement: .topBarLeading) {
              Text(title).font(.headline).lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityAddTraits(.isHeader)
            }
            .sharedBackgroundVisibility(.hidden)
          }
        }
    }
  }

#endif
