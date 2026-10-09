#if os(macOS)
  import Foundation
  import MCP
  import NIOCore
  import NIOHTTP1
  import NIOPosix

  actor PlannerMCPLoopbackListener {
    enum Failure: Error {
      case unavailable
    }

    private let requestHandler: PlannerMCPRequestHandler
    private var eventLoopGroup: MultiThreadedEventLoopGroup?
    private var acceptingChannel: (any Channel)?
    private var servingTask: Task<Void, Never>?

    init(requestHandler: PlannerMCPRequestHandler) {
      self.requestHandler = requestHandler
    }

    func start(port: UInt16 = 44444) async throws -> URL {
      guard acceptingChannel == nil else { throw Failure.unavailable }

      let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
      let bootstrap = ServerBootstrap(group: eventLoopGroup)

      do {
        let serverChannel = try await bootstrap.bind(host: "127.0.0.1", port: Int(port)) {
          channel in
          channel.pipeline.configureHTTPServerPipeline().flatMapThrowing {
            try NIOAsyncChannel<HTTPServerRequestPart, HTTPServerResponsePart>(
              wrappingChannelSynchronously: channel
            )
          }
        }
        guard let boundPort = serverChannel.channel.localAddress?.port,
          let endpoint = URL(string: "http://127.0.0.1:\(boundPort)/mcp")
        else {
          try await serverChannel.channel.close().get()
          throw Failure.unavailable
        }

        self.eventLoopGroup = eventLoopGroup
        acceptingChannel = serverChannel.channel
        let requestHandler = self.requestHandler
        servingTask = Task {
          await Self.serve(serverChannel, requestHandler: requestHandler)
        }
        return endpoint
      } catch {
        try? await eventLoopGroup.shutdownGracefully()
        throw error
      }
    }

    func stop() async {
      await requestHandler.revokeAccess()
      try? await acceptingChannel?.close().get()
      servingTask?.cancel()
      await servingTask?.value
      try? await eventLoopGroup?.shutdownGracefully()
      acceptingChannel = nil
      servingTask = nil
      eventLoopGroup = nil
    }

    private static func serve(
      _ serverChannel: NIOAsyncChannel<
        NIOAsyncChannel<HTTPServerRequestPart, HTTPServerResponsePart>, Never
      >,
      requestHandler: PlannerMCPRequestHandler
    ) async {
      do {
        try await serverChannel.executeThenClose { inbound in
          await withDiscardingTaskGroup { connections in
            do {
              for try await connection in inbound {
                connections.addTask {
                  await withTaskCancellationHandler {
                    try? await respond(connection, requestHandler: requestHandler)
                  } onCancel: {
                    connection.channel.close(promise: nil)
                  }
                }
              }
            } catch {
              connections.cancelAll()
            }
          }
        }
      } catch {
        return
      }
    }

    private static func respond(
      _ connection: NIOAsyncChannel<HTTPServerRequestPart, HTTPServerResponsePart>,
      requestHandler: PlannerMCPRequestHandler
    ) async throws {
      try await connection.executeThenClose { inbound, outbound in
        var requestHead: HTTPRequestHead?
        var requestBody = ByteBufferAllocator().buffer(capacity: 0)

        for try await part in inbound {
          switch part {
          case .head(let head):
            requestHead = head
          case .body(var body):
            requestBody.writeBuffer(&body)
          case .end:
            guard let requestHead else { return }
            var requestHeaders: [String: String] = [:]
            for header in requestHead.headers {
              let name = header.name.lowercased()
              if let previous = requestHeaders[name] {
                requestHeaders[name] = previous + "," + header.value
              } else {
                requestHeaders[name] = header.value
              }
            }

            let request = HTTPRequest(
              method: requestHead.method.rawValue,
              headers: requestHeaders,
              body: Data(requestBody.readableBytesView),
              path: requestHead.uri
            )
            let response = await requestHandler.handleRequest(request)
            let responseBody = response.bodyData ?? Data()
            var responseHeaders = HTTPHeaders(response.headers.map { ($0.key, $0.value) })
            responseHeaders.replaceOrAdd(name: "Content-Length", value: String(responseBody.count))
            responseHeaders.replaceOrAdd(name: "Connection", value: "close")
            let responseHead = HTTPResponseHead(
              version: requestHead.version,
              status: HTTPResponseStatus(statusCode: response.statusCode),
              headers: responseHeaders
            )

            try await outbound.write(.head(responseHead))
            if !responseBody.isEmpty {
              try await outbound.write(.body(.byteBuffer(ByteBuffer(bytes: responseBody))))
            }
            try await outbound.write(.end(nil))
            return
          }
        }
      }
    }
  }
#endif
