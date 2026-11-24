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
}
