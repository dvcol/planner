import XCTest

extension XCUIApplication {
  /// Native Mac rows and menus expose different accessibility roles from mobile navigation buttons.
  func plannerElement(_ identifier: String) -> XCUIElement {
    #if os(macOS)
      descendants(matching: .any)[identifier]
    #else
      buttons[identifier]
    #endif
  }
}

extension XCUIElement {
  func activateForPlannerJourney() {
    #if os(macOS)
      click()
    #else
      tap()
    #endif
  }
}
