import Foundation
import Network

final class BrowserJourneyServer: @unchecked Sendable {
  private let listener: NWListener
  private let queue = DispatchQueue(label: "Planner.BrowserJourneyServer")
  private let lock = NSLock()
  private var port: NWEndpoint.Port?
  private var failure: NWError?
  private var observedRequestLines: [String] = []
  private var visitorCookieName: String?
  private var observedVisitorCookieValues: [String] = []
  private var isGuideAvailable = true
  private var isGardenAvailable = true
  private var connections: [NWConnection] = []
  private var delayedResponses: [(connection: NWConnection, content: Data)] = []
  private var observedDelayedRequests = 0
  private var observedDelayedResponseOutcomes: [String] = []

  init() throws {
    let parameters = NWParameters.tcp
    parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
    listener = try NWListener(using: parameters)
  }

  var requestLines: [String] { lock.withLock { observedRequestLines } }
  var visitorCookieValues: [String] { lock.withLock { observedVisitorCookieValues } }
  var delayedRequestCount: Int { lock.withLock { observedDelayedRequests } }
  var delayedResponseOutcomes: [String] { lock.withLock { observedDelayedResponseOutcomes } }

  func setGuideAvailable(_ available: Bool) { lock.withLock { isGuideAvailable = available } }
  func setGardenAvailable(_ available: Bool) { lock.withLock { isGardenAvailable = available } }
  func setVisitorCookieName(_ name: String) { lock.withLock { visitorCookieName = name } }

  func releaseDelayedResponses() {
    queue.async { [self] in
      for response in delayedResponses {
        response.connection.send(
          content: response.content,
          completion: .contentProcessed { [self] error in
            lock.withLock {
              observedDelayedResponseOutcomes.append(
                error?.localizedDescription ?? "contentProcessed")
            }
            response.connection.cancel()
          })
      }
      delayedResponses.removeAll()
    }
  }

  func start() async throws -> URL {
    listener.stateUpdateHandler = { [weak self] state in
      guard let self else { return }
      lock.withLock {
        if case .ready = state { port = listener.port }
        if case .failed(let error) = state { failure = error }
      }
    }
    listener.newConnectionHandler = { [weak self] connection in
      guard let self else { return }
      connections.append(connection)
      connection.start(queue: queue)
      receive(connection, bytes: Data())
    }
    listener.start(queue: queue)
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while ContinuousClock.now < deadline {
      let observation = lock.withLock { (port, failure) }
      if let failure = observation.1 { throw failure }
      if let port = observation.0,
        let destination = URL(string: "http://localhost:\(port.rawValue)/guide")
      {
        return destination
      }
      try await Task.sleep(for: .milliseconds(10))
    }
    throw URLError(.timedOut)
  }

  func stop() {
    queue.async { [self] in
      listener.cancel()
      for connection in connections { connection.cancel() }
      connections.removeAll()
    }
  }

  private func receive(_ connection: NWConnection, bytes: Data) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) {
      [weak self] incoming, _, complete, error in
      guard let self else { return }
      let received = bytes + (incoming ?? Data())
      guard error == nil, received.count <= 8192 else {
        connection.cancel()
        return
      }
      guard let header = String(data: received, encoding: .utf8), header.contains("\r\n\r\n") else {
        if complete { connection.cancel() } else { receive(connection, bytes: received) }
        return
      }
      let requestLine = header.components(separatedBy: "\r\n").first ?? ""
      lock.withLock { observedRequestLines.append(requestLine) }
      if requestLine == "GET /guide HTTP/1.1", !lock.withLock({ isGuideAvailable }) {
        connection.cancel()
        return
      }
      if requestLine == "GET /garden HTTP/1.1", !lock.withLock({ isGardenAvailable }) {
        connection.cancel()
        return
      }
      let body: String
      var responseHeaders = ""
      var contentType = "text/html; charset=utf-8"
      let cookieName = lock.withLock { visitorCookieName }
      let visitLinks = """
        <a href="/verify-visit">Check visit</a> <a href="/forget-visit">Forget visit</a>
        """
      if let cookieName,
        requestLine.contains(" /remember-visit ") || requestLine.contains(" /forget-visit ")
          || requestLine.contains(" /verify-visit ")
      {
        let heading: String
        if requestLine.contains(" /remember-visit ") {
          responseHeaders =
            "Set-Cookie: \(cookieName)=remembered; Path=/; Max-Age=3600; HttpOnly; SameSite=Lax\r\n"
          heading = "Visit remembered"
        } else if requestLine.contains(" /forget-visit ") {
          responseHeaders =
            "Set-Cookie: \(cookieName)=; Path=/; Max-Age=0; HttpOnly; SameSite=Lax\r\n"
          heading = "Visit forgotten"
        } else {
          let cookies =
            header.components(separatedBy: "\r\n").first(where: {
              $0.lowercased().hasPrefix("cookie:")
            })?.dropFirst("Cookie:".count).split(separator: ";") ?? []
          let cookie = cookies.map { $0.trimmingCharacters(in: .whitespaces) }.first(where: {
            $0.hasPrefix(cookieName + "=")
          })
          let value = cookie.map { String($0.dropFirst(cookieName.count + 1)) }
          lock.withLock { observedVisitorCookieValues.append(value ?? "absent") }
          heading = value == "remembered" ? "Returning visitor" : "Visit not remembered"
        }
        body = """
          <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="color-scheme" content="light dark"><title>Remembered visit</title></head>
          <body><h1>\(heading)</h1>\(visitLinks)</body></html>
          """
      } else if requestLine.contains(" /automatic-app-redirect ") {
        body = """
          <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="color-scheme" content="light dark"><title>Automatic app redirect</title></head>
          <body><h1>Automatic redirect fixture</h1><a href="/garden">Garden guide</a>
          <script>window.addEventListener('load', () => { window.location.assign('maps://?ll=36,140'); });</script>
          </body></html>
          """
      } else if requestLine.contains(" /external-app-policy ") {
        body = """
          <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="color-scheme" content="light dark"><title>External app policy</title></head>
          <body><h1>External app policy fixture</h1>
          <p><a href="mailto:planner-fixture@example.invalid?subject=Planning">Mail link</a></p>
          <p><a href="tel:+810000000000">Phone link</a></p>
          <p><a href="maps://?ll=35,139">Maps link</a></p>
          <a id="generated-mail" href="mailto:planner-fixture@example.invalid?subject=Planning"
            hidden target="_blank">Generated target</a>
          <p><button onclick="document.getElementById('generated-mail').click()">Generated Mail link</button></p>
          <p><a href="/automatic-app-redirect">Automatic Maps redirect</a></p>
          <a href="/garden">Garden guide</a></body></html>
          """
      } else if requestLine.contains(" /link-policy ") {
        body = """
          <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="color-scheme" content="light dark"><title>Link policy</title></head>
          <body><h1>Link policy fixture</h1>
          <a href="planner-fixture-unsupported://guide">Unavailable app link</a>
          <a href="/garden">Garden guide</a></body></html>
          """
      } else if requestLine.contains(" /unsupported-content ") {
        contentType = "application/x-planner-fixture"
        responseHeaders = "X-Content-Type-Options: nosniff\r\n"
        body = "Unsupported museum content fixture"
      } else if requestLine.contains(" /download-guide ") {
        responseHeaders = "Content-Disposition: attachment; filename=\"guide.txt\"\r\n"
        body = "Museum download fixture"
      } else if requestLine.contains(" /delayed-guide ") {
        body = """
          <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="color-scheme" content="light dark"><title>Delayed guide</title></head>
          <body><h1>Delayed guide fixture</h1><p>The pending response is now available.</p></body></html>
          """
      } else if requestLine.contains(" /garden ") {
        body = """
          <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="color-scheme" content="light dark"><title>Garden guide</title></head>
          <body><h1>Garden guide fixture</h1><p>Enter through the east gate.</p></body></html>
          """
      } else {
        let cookieLinks =
          cookieName == nil ? "" : "<a href=\"/remember-visit\">Remember visit</a> " + visitLinks
        body = """
          <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="color-scheme" content="light dark"><title>Museum guide</title></head>
          <body><h1>Museum guide fixture</h1><p>Meet at the garden entrance.</p>
          <a href="/garden">Garden guide</a> <a href="/delayed-guide">Delayed guide</a>
          <a href="/garden" target="_blank">Garden in another window</a>
          <a href="/unsupported-content">Unsupported content</a>
          <a href="/download-guide" download="guide.txt">Download guide</a>\(cookieLinks)</body></html>
          """
      }
      let content = requestLine.hasPrefix("HEAD ") ? "" : body
      let response =
        "HTTP/1.1 200 OK\r\nContent-Type: \(contentType)\r\nCache-Control: no-store\r\n\(responseHeaders)Content-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(content)"
      if requestLine == "GET /delayed-guide HTTP/1.1" {
        delayedResponses.append((connection, Data(response.utf8)))
        lock.withLock { observedDelayedRequests += 1 }
        return
      }
      connection.send(
        content: Data(response.utf8),
        completion: .contentProcessed { _ in connection.cancel() })
    }
  }
}
