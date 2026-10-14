import Foundation
import PlannerCore
import Testing

struct CaptureHTTPTransportTests {
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
