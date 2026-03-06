import Vapor
import Fluent
import SharedModels

struct WidgetServeController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let w = routes.grouped("w")
        let protected = w.grouped(WidgetCookieMiddleware())
        protected.get(":slug", use: serve)
        protected.on(.GET, ":slug", "**", use: proxyRoute)
        protected.on(.POST, ":slug", "**", use: proxyRoute)
        protected.on(.PUT, ":slug", "**", use: proxyRoute)
        protected.on(.DELETE, ":slug", "**", use: proxyRoute)
        protected.on(.PATCH, ":slug", "**", use: proxyRoute)
    }

    @Sendable
    func serve(req: Request) async throws -> Response {
        guard let slug = req.parameters.get("slug") else { throw Abort(.badRequest) }
        guard let widget = try await Widget.query(on: req.db)
            .filter(\.$slug == slug)
            .first() else {
            throw Abort(.notFound, reason: "Widget '\(slug)' not found")
        }

        // Parse TC:VARS defaults from HTML
        let defaults = WidgetSectionParser.parseVarsDefaults(from: widget.html)

        // Strip TC:ROUTES (not for the browser)
        var html = WidgetSectionParser.stripRoutes(from: widget.html)

        // Inject render vars (live overrides defaults)
        html = WidgetSectionParser.injectVars(defaults: defaults, live: widget.renderVars, into: html)

        let response = Response(status: .ok, body: .init(string: html))
        response.headers.contentType = .html
        response.headers.replaceOrAdd(name: "Cache-Control", value: "no-cache")
        return response
    }

    @Sendable
    func proxyRoute(req: Request) async throws -> Response {
        guard let slug = req.parameters.get("slug") else { throw Abort(.badRequest) }

        guard let widget = try await Widget.query(on: req.db)
            .filter(\.$slug == slug)
            .first(),
            let widgetId = widget.id else {
            throw Abort(.notFound, reason: "Widget '\(slug)' not found")
        }

        // Extract sub-path after /w/:slug
        let fullPath = req.url.path
        let prefix = "/w/\(slug)"
        let routePath = String(fullPath.dropFirst(prefix.count))

        // Parse request body
        var body: Any?
        if let bodyData = req.body.data {
            var buf = bodyData
            if let bytes = buf.readBytes(length: buf.readableBytes) {
                body = try? JSONSerialization.jsonObject(with: Data(bytes))
            }
        }

        // Parse query params
        var query: [String: String]?
        if let urlQuery = req.url.query, !urlQuery.isEmpty {
            var q = [String: String]()
            for pair in urlQuery.split(separator: "&") {
                let parts = pair.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).removingPercentEncoding ?? String(parts[0])
                    let val = String(parts[1]).removingPercentEncoding ?? String(parts[1])
                    q[key] = val
                }
            }
            if !q.isEmpty { query = q }
        }

        // Forward subset of headers
        var headers = [String: String]()
        for name in ["content-type", "accept", "authorization", "x-widget-token"] {
            if let val = req.headers.first(name: name) {
                headers[name] = val
            }
        }

        // Execute in sandbox
        let (status, json) = try await req.sandboxClient.execute(
            widgetId: widgetId.uuidString,
            method: req.method.string,
            path: routePath.isEmpty ? "/" : routePath,
            body: body,
            query: query,
            headers: headers.isEmpty ? nil : headers
        )

        // Log errors and post system message for self-healing
        if status >= 500, let widgetId = widget.id {
            Task {
                await Self.logWidgetError(
                    db: req.db,
                    clientWSManager: req.application.clientWSManager,
                    widget: widget,
                    widgetId: widgetId,
                    method: req.method.string,
                    routePath: routePath.isEmpty ? "/" : routePath,
                    json: json,
                    logger: req.logger
                )
            }
        }

        let responseData = try JSONSerialization.data(withJSONObject: json)
        let response = Response(
            status: HTTPResponseStatus(statusCode: status),
            body: .init(data: responseData)
        )
        response.headers.contentType = .json
        return response
    }

    /// Log widget route errors to DB and inject a system message into the originating chat session.
    private static func logWidgetError(
        db: any Database,
        clientWSManager: ClientWSManager,
        widget: Widget,
        widgetId: UUID,
        method: String,
        routePath: String,
        json: [String: Any],
        logger: Logger
    ) async {
        let errorMessage = (json["error"] as? String) ?? "Unknown error"
        let stackTrace = json["stack"] as? String

        // Find the matching route for the error log FK
        let route = try? await WidgetRoute.query(on: db)
            .filter(\.$widget.$id == widgetId)
            .filter(\.$method == method)
            .filter(\.$path == routePath)
            .first()

        // Save error log
        if let routeId = route?.id {
            let errorLog = WidgetErrorLog()
            errorLog.id = UUID()
            errorLog.$widget.id = widgetId
            errorLog.$route.id = routeId
            errorLog.errorMessage = errorMessage
            errorLog.stackTrace = stackTrace
            errorLog.requestPath = routePath
            errorLog.notifiedSession = widget.createdBySession
            try? await errorLog.save(on: db)
        }

        // Post system message to the originating chat session
        guard let sessionId = widget.createdBySession else {
            logger.warning("Widget \(widget.slug) error but no createdBySession — cannot notify agent")
            return
        }

        // Extract current TC:ROUTES for agent context
        let routesSection = WidgetSectionParser.parseSections(from: widget.html)["TC:ROUTES"] ?? "(unavailable)"

        let systemText = """
        [Widget Error] slug: \(widget.slug)
        Route: \(method) \(routePath)
        Error: \(errorMessage)
        Stack: \(stackTrace ?? "(no stack trace)")
        Widget HTML (TC:ROUTES section):
        \(routesSection)
        """

        if let message = try? Message(sessionId: sessionId, role: .system, content: .text(systemText)) {
            try? await message.save(on: db)
            logger.info("Posted widget error system message to session \(sessionId)")

            // Notify iOS client so they see the error message
            if let session = try? await Session.find(sessionId, on: db) {
                session.lastMessageAt = Date()
                try? await session.save(on: db)
                await clientWSManager.sendToSession(
                    .sessionUpdated(session.toDTO()),
                    sessionId: sessionId,
                    logger: logger
                )
            }
        }
    }
}
