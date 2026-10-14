import Foundation

/// One header-only request. Core owns provider eligibility, redirects and the attempt budget.
public protocol PlannerCaptureHTTPTransport: Sendable {
  func head(requestURL: URL, timeout: Duration) async throws -> HTTPURLResponse
}

public struct PlannerNativeCaptureHTTPTransport: PlannerCaptureHTTPTransport {
  private let configuration: URLSessionConfiguration

  public init(configuration: URLSessionConfiguration = .ephemeral) {
    self.configuration = configuration.copy() as! URLSessionConfiguration
  }

  public func head(requestURL: URL, timeout: Duration) async throws -> HTTPURLResponse {
    let seconds =
      Double(timeout.components.seconds)
      + Double(timeout.components.attoseconds) / 1_000_000_000_000_000_000
    guard seconds.isFinite, seconds > 0, configuration.identifier == nil else {
      throw URLError(.badURL)
    }
    var request = URLRequest(url: requestURL, timeoutInterval: seconds)
    request.httpMethod = "HEAD"
    request.cachePolicy = .reloadIgnoringLocalCacheData
    let requestConfiguration = configuration.copy() as! URLSessionConfiguration
    requestConfiguration.timeoutIntervalForRequest = seconds
    requestConfiguration.timeoutIntervalForResource = seconds
    let operation = PlannerCaptureHeaderOperation(
      request: request, configuration: requestConfiguration)
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        operation.start(continuation)
      }
    } onCancel: {
      operation.finish(.failure(CancellationError()))
    }
  }
}

private final class PlannerCaptureHeaderOperation: NSObject, URLSessionDataDelegate,
  @unchecked Sendable
{
  private let lock = NSLock()
  private let request: URLRequest
  private let configuration: URLSessionConfiguration
  private var result: Result<HTTPURLResponse, Error>?
  private var continuation: CheckedContinuation<HTTPURLResponse, Error>?
  private var session: URLSession?
  private var task: URLSessionDataTask?

  init(request: URLRequest, configuration: URLSessionConfiguration) {
    self.request = request
    self.configuration = configuration
  }

  func start(_ continuation: CheckedContinuation<HTTPURLResponse, Error>) {
    let pending: (task: URLSessionDataTask?, result: Result<HTTPURLResponse, Error>?) =
      lock.withLock {
        if let result { return (nil, result) }
        self.continuation = continuation
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session
        let task = session.dataTask(with: request)
        self.task = task
        return (task, nil)
      }
    if let result = pending.result {
      continuation.resume(with: result)
      return
    }
    pending.task?.resume()
  }

  func finish(_ outcome: Result<HTTPURLResponse, Error>) {
    let pending:
      (continuation: CheckedContinuation<HTTPURLResponse, Error>?, session: URLSession?) =
        lock.withLock {
          guard result == nil else { return (nil, nil) }
          result = outcome
          let pending = (continuation, session)
          continuation = nil
          session = nil
          task = nil
          return pending
        }
    pending.session?.invalidateAndCancel()
    pending.continuation?.resume(with: outcome)
  }

  func urlSession(
    _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
  ) {
    completionHandler(.cancel)
    guard let response = response as? HTTPURLResponse else {
      finish(.failure(URLError(.badServerResponse)))
      return
    }
    finish(.success(response))
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    completionHandler(nil)
    finish(.success(response))
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
  ) {
    finish(.failure(error ?? URLError(.badServerResponse)))
  }
}
