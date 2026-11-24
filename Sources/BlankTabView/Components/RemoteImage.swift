import SwiftUI
import UIKit

/// QQ 图床要 Referer / UA，系统 `AsyncImage` 不带，头像因此会阴默失败。
/// 这里统一走一个带请求头 + 内存缓存的图片加载入口，全 App 只此一套。
enum RemoteImageLoader {
    private static let cache = NSCache<NSString, UIImage>()
    private static let lock = NSLock()
    private static var tasks: [String: Task<UIImage?, Never>] = [:]

    /// http → https、补全协议头。
    static func normalize(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return "" }
        if text.hasPrefix("//") { text = "https:" + text }
        if text.hasPrefix("http://") {
            text = "https://" + text.dropFirst("http://".count)
        }
        return text
    }

    static func cached(_ raw: String) -> UIImage? {
        let key = normalize(raw)
        guard !key.isEmpty else { return nil }
        return cache.object(forKey: key as NSString)
    }

    static func image(for raw: String) async -> UIImage? {
        let key = normalize(raw)
        guard let url = URL(string: key) else { return nil }
        if let hit = cache.object(forKey: key as NSString) { return hit }

        lock.lock()
        if let running = tasks[key] {
            lock.unlock()
            return await running.value
        }
        let task = Task<UIImage?, Never> { () -> UIImage? in
            var request = URLRequest(url: url, timeoutInterval: 20)
            for (field, value) in QqHttp.browserHeaders {
                request.setValue(value, forHTTPHeaderField: field)
            }
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode ?? 200 < 400,
                  let image = UIImage(data: data) else { return nil }
            cache.setObject(image, forKey: key as NSString)
            return image
        }
        tasks[key] = task
        lock.unlock()

        let result = await task.value
        lock.lock()
        tasks[key] = nil
        lock.unlock()
        return result
    }
}
