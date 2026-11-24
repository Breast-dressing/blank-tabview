import Foundation

struct ApiError: LocalizedError, Sendable {
    let message: String
    var code: Int?

    var errorDescription: String? { message }

    init(_ message: String, code: Int? = nil) {
        self.message = message
        self.code = code
    }
}

/// 全项目唯一的 HTTP 出口：统一 UA / Referer，统一超时与错误文案。
final class QqHttp: @unchecked Sendable {
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
        + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    static let browserHeaders: [String: String] = [
        "User-Agent": userAgent,
        "Referer": "https://y.qq.com/",
        "Origin": "https://y.qq.com",
        "Accept": "application/json, text/plain, */*"
    ]

    private let session: URLSession

    init(timeout: TimeInterval = 20) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        session = URLSession(configuration: configuration)
    }

    func getText(_ url: String, headers: [String: String]? = nil, timeout: TimeInterval? = nil) async throws -> String {
        guard let urlObject = URL(string: url) else { throw ApiError("链接格式不正确") }
        var request = URLRequest(url: urlObject)
        request.timeoutInterval = timeout ?? 20
        for (key, value) in Self.browserHeaders { request.setValue(value, forHTTPHeaderField: key) }
        if let headers {
            for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw ApiError("上游请求超时，请稍后重试")
        } catch let error as URLError {
            throw ApiError(friendly(error, host: urlObject.host ?? ""))
        } catch {
            throw ApiError("网络请求失败：\(error.localizedDescription)")
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        if status >= 400 { throw ApiError("网络请求失败（HTTP \(status)）") }
        return decodeBody(data, contentType: (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "content-type") ?? "")
    }

    func postJSON(_ url: String, body: String, headers: [String: String]? = nil, timeout: TimeInterval? = nil) async throws -> Any {
        guard let urlObject = URL(string: url) else { throw ApiError("链接格式不正确") }
        var request = URLRequest(url: urlObject)
        request.httpMethod = "POST"
        request.httpBody = Data(body.utf8)
        request.timeoutInterval = timeout ?? 20
        for (key, value) in Self.browserHeaders { request.setValue(value, forHTTPHeaderField: key) }
        request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        if let headers {
            for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw ApiError("上游请求超时，请稍后重试")
        } catch let error as URLError {
            throw ApiError(friendly(error, host: urlObject.host ?? ""))
        } catch {
            throw ApiError("网络请求失败：\(error.localizedDescription)")
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        if status >= 400 { throw ApiError("上游接口异常（HTTP \(status)）") }
        let text = decodeBody(data, contentType: (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "content-type") ?? "")
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) else {
            throw ApiError("接口解析失败：返回不是合法 JSON")
        }
        return object
    }

    func getBytes(_ url: String, timeout: TimeInterval = 15) async -> Data? {
        guard let urlObject = URL(string: url) else { return nil }
        var request = URLRequest(url: urlObject)
        request.timeoutInterval = timeout
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue("image/*,*/*", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await session.data(for: request) else { return nil }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        if status >= 400 { return nil }
        let type = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "content-type") ?? ""
        if type.hasPrefix("text/") || type.contains("json") { return nil }
        return data
    }

    private func decodeBody(_ data: Data, contentType: String) -> String {
        if contentType.contains("gbk") || contentType.contains("gb2312") {
            return String(data: data, encoding: .isoLatin1) ?? ""
        }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }

    private func friendly(_ error: URLError, host: String) -> String {
        let suffix = host.isEmpty ? "" : "（\(host)）"
        switch error.code {
        case .cannotFindHost, .dnsLookupFailed:
            return "域名解析失败\(suffix)：当前网络无法解析该域名，请切换 Wi‑Fi / 蜂窝网络，或改用家族页完整链接"
        case .cannotConnectToHost:
            return "连接被拒绝\(suffix)，请检查网络代理设置"
        case .notConnectedToInternet, .networkConnectionLost:
            return "网络不可达，请检查网络连接"
        case .timedOut:
            return "上游请求超时，请稍后重试"
        default:
            return "网络连接失败\(suffix)，请稍后重试"
        }
    }
}

/// 给不便拆分的 async 调用加整体超时（对应 Dart 的 `.timeout(...)`）。
enum AsyncTimeout {
    static func run<T: Sendable>(seconds: Double, operation: @Sendable @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ApiError("上游请求超时，请稍后重试")
            }
            guard let result = try await group.next() else {
                throw ApiError("上游请求超时，请稍后重试")
            }
            group.cancelAll()
            return result
        }
    }
}
