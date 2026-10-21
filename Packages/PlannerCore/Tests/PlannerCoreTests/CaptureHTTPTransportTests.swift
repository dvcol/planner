import Foundation
import Network
import PlannerCore
import Testing

struct CaptureHTTPTransportTests {
  @Test func nativeSocketRequestUsesHEADAndClosesAfterReceivingHeaders() async throws {
    let server = try CaptureSocketServer()
    defer { server.stop() }
    let requestURL = try await server.start()
    let transport = PlannerNativeCaptureHTTPTransport()
    let response = try await transport.head(requestURL: requestURL, timeout: .seconds(4))
    #expect(response.statusCode == 200)
    #expect(response.value(forHTTPHeaderField: "X-Capture-Fixture") == "loopback")
    #expect(server.requestLine == "HEAD /capture HTTP/1.1")
    let didClose = try await server.waitForPeerClosure()
    #expect(didClose)
  }

  @Test func cancellingPendingNativeSocketRequestClosesItsConnection() async throws {
    let server = try CaptureSocketServer(response: .pending)
    defer { server.stop() }
    let requestURL = try await server.start()
    let transport = PlannerNativeCaptureHTTPTransport()
    let requestTask = Task {
      try await transport.head(requestURL: requestURL, timeout: .seconds(4))
    }
    defer { requestTask.cancel() }
    let didReceiveRequest = try await server.waitForRequest()
    try #require(didReceiveRequest)
    #expect(server.requestLine == "HEAD /capture HTTP/1.1")
    requestTask.cancel()
    await #expect(throws: CancellationError.self) { try await requestTask.value }
    let didClose = try await server.waitForPeerClosure()
    #expect(didClose)
  }

  @Test func nativeSocketRedirectReturnsFirstHopAndClosesItsConnection() async throws {
    let server = try CaptureSocketServer(response: .redirect)
    defer { server.stop() }
    let requestURL = try await server.start()
    let transport = PlannerNativeCaptureHTTPTransport()
    let response = try await transport.head(requestURL: requestURL, timeout: .seconds(4))
    #expect(response.statusCode == 301)
    #expect(response.url == requestURL)
    #expect(response.value(forHTTPHeaderField: "Location") == "/unexpected-follow")
    let didClose = try await server.waitForPeerClosure()
    #expect(didClose)
    #expect(server.requestLine == "HEAD /capture HTTP/1.1")
  }

  @Test func nativeSocketTimeoutClosesThePendingConnection() async throws {
    let server = try CaptureSocketServer(response: .pending)
    defer { server.stop() }
    let requestURL = try await server.start()
    let transport = PlannerNativeCaptureHTTPTransport()
    let clock = ContinuousClock()
    let started = clock.now
    do {
      _ = try await transport.head(requestURL: requestURL, timeout: .seconds(1))
      Issue.record("A socket that never supplies headers must time out.")
    } catch let error as URLError {
      #expect(error.code == .timedOut)
    }
    #expect(started.duration(to: clock.now) < .seconds(3))
    #expect(server.requestLine == "HEAD /capture HTTP/1.1")
    let didClose = try await server.waitForPeerClosure()
    #expect(didClose)
  }

  @Test func nativeRequestTimesOutWhenNoHeadersArrive() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CaptureHeaderProtocol.self]
    let transport = PlannerNativeCaptureHTTPTransport(configuration: configuration)
    let requestURL = try #require(URL(string: "https://maps.apple.com/pending"))
    let clock = ContinuousClock()
    let started = clock.now
    do {
      _ = try await transport.head(requestURL: requestURL, timeout: .milliseconds(50))
      Issue.record("A pending header request must time out.")
    } catch let error as URLError {
      #expect(error.code == .timedOut)
    }
    #expect(started.duration(to: clock.now) < .seconds(2))
  }

  @Test func nativeTransportReturnsRedirectHeadersWithoutFollowingTheNextRequest() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CaptureHeaderProtocol.self]
    let transport = PlannerNativeCaptureHTTPTransport(configuration: configuration)
    let requestURL = try #require(URL(string: "https://maps.apple.com/redirect"))
    let response = try await transport.head(requestURL: requestURL, timeout: .seconds(4))
    #expect(response.statusCode == 301)
    #expect(response.url?.path == "/redirect")
    #expect(
      response.value(forHTTPHeaderField: "Location") == "https://maps.apple.com/unexpected-follow")
  }

  @Test(arguments: ["beforeStartup", "pendingIO"])
  func cancelledNativeRequestReturnsCancellationBeforeItsTimeout(cancellationPhase: String)
    async throws
  {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CaptureHeaderProtocol.self]
    let transport = PlannerNativeCaptureHTTPTransport(configuration: configuration)
    let requestURL = try #require(URL(string: "https://maps.apple.com/pending-cancel"))
    let requestTask = Task {
      if cancellationPhase == "beforeStartup" {
        withUnsafeCurrentTask { currentTask in currentTask?.cancel() }
      }
      return try await transport.head(requestURL: requestURL, timeout: .seconds(4))
    }
    defer { requestTask.cancel() }
    if cancellationPhase == "pendingIO" {
      let didStart = try await CaptureHeaderProtocol.cancellationRequestStarted.wait()
      #expect(didStart)
      requestTask.cancel()
    }
    await #expect(throws: CancellationError.self) { try await requestTask.value }
  }

  @Test func nativeTransportUsesHEADAndReturnsStatusAndHeaders() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CaptureHeaderProtocol.self]
    let transport = PlannerNativeCaptureHTTPTransport(configuration: configuration)
    let requestURL = try #require(URL(string: "https://maps.apple.com/transport-fixture"))
    let response = try await transport.head(requestURL: requestURL, timeout: .seconds(4))
    #expect(response.statusCode == 301)
    #expect(
      response.value(forHTTPHeaderField: "Location") == "https://maps.apple.com/place?name=Museum")
    #expect(response.value(forHTTPHeaderField: "X-Observed-Method") == "HEAD")
  }
}

/// Connections stay on one queue; only observations cross into the test task under the lock.
private final class CaptureSocketServer: @unchecked Sendable {
  enum Response {
    case headers, redirect, pending
  }

  private let listener: NWListener
  private let queue = DispatchQueue(label: "Planner.CaptureSocketFixture")
  private let lock = NSLock()
  private let response: Response
  private var port: NWEndpoint.Port?
  private var failure: NWError?
  private var observedRequestLine: String?
  private var peerClosed = false
  private var connections: [NWConnection] = []

  init(response: Response = .headers) throws {
    self.response = response
    let parameters = NWParameters.tcp
    parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
    listener = try NWListener(using: parameters)
  }

  var requestLine: String? { lock.withLock { observedRequestLine } }

  func start() async throws -> URL {
    listener.stateUpdateHandler = { [weak self] state in
      guard let self else { return }
      self.lock.withLock {
        if case .ready = state { self.port = self.listener.port }
        if case .failed(let error) = state { self.failure = error }
      }
    }
    listener.newConnectionHandler = { [weak self] connection in
      guard let self else { return }
      self.connections.append(connection)
      connection.start(queue: self.queue)
      self.receive(connection, request: Data(), responded: false)
    }
    listener.start(queue: queue)
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while clock.now < deadline {
      let observation = lock.withLock { (port, failure) }
      if let failure = observation.1 { throw failure }
      if let port = observation.0 {
        return URL(string: "http://127.0.0.1:\(port.rawValue)/capture")!
      }
      try await Task.sleep(for: .milliseconds(5))
    }
    throw URLError(.timedOut)
  }

  func waitForPeerClosure() async throws -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while clock.now < deadline {
      if lock.withLock({ peerClosed }) { return true }
      try await Task.sleep(for: .milliseconds(5))
    }
    return false
  }

  func waitForRequest() async throws -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while clock.now < deadline {
      if requestLine != nil { return true }
      try await Task.sleep(for: .milliseconds(5))
    }
    return false
  }

  func stop() {
    queue.async { [self] in
      listener.cancel()
      for connection in connections { connection.cancel() }
      connections.removeAll()
    }
  }

  private func receive(_ connection: NWConnection, request: Data, responded: Bool) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) {
      [weak self] data, _, complete, error in
      guard let self else { return }
      if complete || error != nil {
        self.lock.withLock { self.peerClosed = true }
        return
      }
      var request = request
      var responded = responded
      if let data, !responded {
        request.append(data)
        guard request.count <= 8192 else {
          connection.cancel()
          return
        }
        if let header = String(data: request, encoding: .utf8), header.contains("\r\n\r\n") {
          self.lock.withLock {
            self.observedRequestLine = header.components(separatedBy: "\r\n").first
          }
          self.sendResponse(connection, requestLine: self.requestLine)
          responded = true
        }
      }
      self.receive(connection, request: request, responded: responded)
    }
  }

  private func sendResponse(_ connection: NWConnection, requestLine: String?) {
    if case .pending = response { return }
    let statusAndHeaders: String
    if case .redirect = response, requestLine == "HEAD /capture HTTP/1.1" {
      statusAndHeaders = "301 Moved Permanently\r\nLocation: /unexpected-follow"
    } else {
      statusAndHeaders = "200 OK\r\nX-Capture-Fixture: loopback"
    }
    let response =
      "HTTP/1.1 \(statusAndHeaders)\r\nContent-Length: 0\r\nConnection: keep-alive\r\n\r\n"
    connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in })
  }
}

private final class CaptureHeaderProtocol: URLProtocol, @unchecked Sendable {
  static let cancellationRequestStarted = CapturePendingRequestObservation()
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    if request.url?.path == "/pending-cancel" {
      Task { await Self.cancellationRequestStarted.signal() }
      return
    }
    guard request.url?.path != "/pending" else { return }
    guard let requestURL = request.url else { return }
    let location: String
    if requestURL.path == "/redirect" {
      location = "https://maps.apple.com/unexpected-follow"
    } else {
      location = "https://maps.apple.com/place?name=Museum"
    }
    guard
      let response = HTTPURLResponse(
        url: requestURL, statusCode: requestURL.path == "/unexpected-follow" ? 200 : 301,
        httpVersion: "HTTP/1.1",
        headerFields: [
          "Location": location,
          "X-Observed-Method": request.httpMethod ?? "missing",
        ])
    else { return }
    if requestURL.path == "/redirect",
      let destination = URL(string: "https://maps.apple.com/unexpected-follow")
    {
      client?.urlProtocol(
        self, wasRedirectedTo: URLRequest(url: destination), redirectResponse: response)
      return
    }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

private actor CapturePendingRequestObservation {
  private var started = false

  func wait() async throws -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while !started, clock.now < deadline {
      try await Task.sleep(for: .milliseconds(5))
    }
    return started
  }

  func signal() {
    started = true
  }
}
