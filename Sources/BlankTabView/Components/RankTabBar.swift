import SwiftUI
import UIKit

/// 工具栏分段 tab：桥接系统原生 `UISegmentedControl`（不自绘）。
/// 段宽由系统按标签文本排版宽度决定（不自绘）。
struct RankTabBar: UIViewRepresentable {
    let titles: [String]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: titles)
        control.apportionsSegmentWidthsByContent = false
        control.selectedSegmentIndex = clampedIndex
        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        applyWidths(to: control)
        return control
    }

    func updateUIView(_ control: UISegmentedControl, context: Context) {
        context.coordinator.onSelect = onSelect
        if control.numberOfSegments != titles.count {
            control.removeAllSegments()
            for (index, title) in titles.enumerated() {
                control.insertSegment(withTitle: title, at: index, animated: false)
            }
        } else {
            for (index, title) in titles.enumerated() {
                control.setTitle(title, forSegmentAt: index)
            }
        }
        applyWidths(to: control)
        if control.selectedSegmentIndex != clampedIndex {
            control.selectedSegmentIndex = clampedIndex
        }
    }

    /// 控件只占「各段文本宽度之和」，高度沿用系统默认按钮高度（不自定义）。
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        CGSize(width: Self.totalWidth(titles: titles), height: uiView.intrinsicContentSize.height)
    }

    /// 段宽 = 该标签文本排版宽度 + 左右内边距，让文字贴近按钮背景边缘。
    private func applyWidths(to control: UISegmentedControl) {
        for index in 0..<control.numberOfSegments {
            let title = control.titleForSegment(at: index) ?? ""
            control.setWidth(Self.segmentWidth(title: title), forSegmentAt: index)
        }
    }

    private static func totalWidth(titles: [String]) -> CGFloat {
        titles.reduce(0) { $0 + segmentWidth(title: $1) }
    }

    /// 单侧内边距：8pt（比系统默认的 12pt 更贴边，同时留出系统文本内缩不截断）。
    private static let horizontalPadding: CGFloat = 8

    private static func segmentWidth(title: String) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
        return ceil(textWidth) + horizontalPadding * 2
    }

    private var clampedIndex: Int {
        titles.isEmpty ? UISegmentedControl.noSegment : min(max(selectedIndex, 0), titles.count - 1)
    }

    final class Coordinator: NSObject {
        var onSelect: (Int) -> Void

        init(onSelect: @escaping (Int) -> Void) {
            self.onSelect = onSelect
        }

        @objc func valueChanged(_ sender: UISegmentedControl) {
            guard sender.selectedSegmentIndex != UISegmentedControl.noSegment else { return }
            onSelect(sender.selectedSegmentIndex)
        }
    }
}
