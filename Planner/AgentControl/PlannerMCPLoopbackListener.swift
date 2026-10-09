#if os(macOS)
  import Foundation
  import MCP
  import NIOCore
  import NIOHTTP1
  import NIOPosix
  import Synchronization

  actor PlannerMCPLoopbackListener {
    enum Failure: Error {
      case unavailable
    }

    private let requestHandler: PlannerMCPRequestHandler
    private var eventLoopGroup: MultiThreadedEventLoopGroup?
    private var acceptingChannel: (any Channel)?
    private var servingTask: Task<Void, Never>?
    private var acceptedConnections: PlannerMCPAcceptedConnections?

    init(requestHandler: PlannerMCPRequestHandler) {
      self.requestHandler = requestHandler
    }

    func start(port: UInt16 = 44444) async throws -> URL {
      guard acceptingChannel == nil else { throw Failure.unavailable }

      let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
      let bootstrap = ServerBootstrap(group: eventLoopGroup)
        .childChannelOption(ChannelOptions.autoRead, value: false)
      let acceptedConnections = PlannerMCPAcceptedConnections()

      do {
        let serverChannel: NIOAsyncChannel<any Channel, Never> = try await bootstrap.bind(
          host: "127.0.0.1", port: Int(port)
        ) {
          channel in
          guard acceptedConnections.register(channel) else {
            return channel.eventLoop.makeFailedFuture(Failure.unavailable)
          }
          return channel.pipeline.configureHTTPServerPipeline().map { channel }
        }
        guard let boundPort = serverChannel.channel.localAddress?.port,
          let endpoint = URL(string: "http://127.0.0.1:\(boundPort)/mcp")
        else {
          try await serverChannel.channel.close().get()
          throw Failure.unavailable
        }

        self.eventLoopGroup = eventLoopGroup
        self.acceptedConnections = acceptedConnections
        acceptingChannel = serverChannel.channel
        let requestHandler = self.requestHandler
        servingTask = Task {
          await Self.serve(serverChannel, requestHandler: requestHandler)
        }
        return endpoint
      } catch {
        acceptedConnections.closeAll()
        try? await eventLoopGroup.shutdownGracefully()
        throw error
      }
    }

    func stop() async {
      await requestHandler.revokeAccess()
      acceptedConnections?.closeAll()
      try? await acceptingChannel?.close().get()
      servingTask?.cancel()
      await servingTask?.value
      try? await eventLoopGroup?.shutdownGracefully()
      acceptingChannel = nil
      servingTask = nil
      eventLoopGroup = nil
      acceptedConnections = nil
    }

    private static func serve(
      _ serverChannel: NIOAsyncChannel<any Channel, Never>,
      requestHandler: PlannerMCPRequestHandler
    ) async {
      do {
        try await serverChannel.executeThenClose { inbound in
          await withDiscardingTaskGroup { connections in
            defer { connections.cancelAll() }
            do {
              for try await connection in inbound {
                connections.addTask {
                  await withTaskCancellationHandler {
                    try? await respond(connection, requestHandler: requestHandler)
                  } onCancel: {
                    connection.close(promise: nil)
                  }
                }
              }
            } catch {
              return
            }
          }
        }
      } catch {
        return
      }
    }

    private static func respond(
      _ channel: any Channel,
      requestHandler: PlannerMCPRequestHandler
    ) async throws {
      let connection = try await channel.eventLoop.submit {
        try NIOAsyncChannel<HTTPServerRequestPart, HTTPServerResponsePart>(
          wrappingChannelSynchronously: channel)
      }.get()
      try await connection.executeThenClose { inbound, outbound in
        try await channel.setOption(ChannelOptions.autoRead, value: true).get()
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

  private final class PlannerMCPAcceptedConnections: Sendable {
    private struct State {
      var channels: [ObjectIdentifier: any Channel] = [:]
      var isStopping = false
    }

    private let state = Mutex(State())

    func register(_ channel: any Channel) -> Bool {
      let identity = ObjectIdentifier(channel)
      let registered = state.withLock { state in
        guard !state.isStopping else { return false }
        state.channels[identity] = channel
        return true
      }
      guard registered else {
        channel.close(promise: nil)
        return false
      }
      channel.closeFuture.whenComplete { [weak self] _ in
        self?.state.withLock { state in
          _ = state.channels.removeValue(forKey: identity)
        }
      }
      return true
    }

    func closeAll() {
      let channels = state.withLock { state in
        state.isStopping = true
        let channels = Array(state.channels.values)
        state.channels.removeAll()
        return channels
      }
      for channel in channels {
        channel.close(promise: nil)
      }
    }
  }
#endif
