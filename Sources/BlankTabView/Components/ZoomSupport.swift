import SwiftUI

/// iOS 18+ zoom 过渡的“出发地”；没有 namespace 时原样返回。
private struct MatchedSourceIfAvailable: ViewModifier {
    let id: String
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

/// 给 sheet / 导航目标挂 zoom 过渡；没有 namespace 时原样返回。
private struct ZoomNavigationIfAvailable: ViewModifier {
    let id: String
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

extension View {
    func matchedTransitionSourceIfAvailable(id: String, in namespace: Namespace.ID?) -> some View {
        modifier(MatchedSourceIfAvailable(id: id, namespace: namespace))
    }

    func zoomNavigationTransitionIfAvailable(id: String, in namespace: Namespace.ID?) -> some View {
        modifier(ZoomNavigationIfAvailable(id: id, namespace: namespace))
    }
}
