import SwiftUI

/// 页面顶部左侧的标题。
struct PageTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    PageTitle(text: "我的")
        .padding()
}
