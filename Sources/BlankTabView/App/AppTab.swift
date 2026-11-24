import Foundation

/// TabView 的三个页面：首页、我的、搜索。
enum AppTab: String, CaseIterable, Identifiable {
    case home
    case profile
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "首页"
        case .profile: "我的"
        case .search: "搜索"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .profile: "person"
        case .search: "magnifyingglass"
        }
    }

    /// 截图 / 自动化用：启动参数 `-startTab profile` 指定首个页面。
    static var launchTab: AppTab {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-startTab"), index + 1 < args.count,
           let tab = AppTab(rawValue: args[index + 1]) {
            return tab
        }
        return .home
    }
}
