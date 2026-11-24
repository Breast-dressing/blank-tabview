import SwiftUI

/// 搜索：左上角大标题 + 页内搜索框；作为分离式 Tab（role: .search）。
struct SearchPage: View {
    @State private var query = ""

    var body: some View {
        NavigationStack {
            PageScaffold(title: AppTab.search.title) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("搜索", text: $query)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .submitLabel(.search)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    }

                    if query.isEmpty {
                        Text("输入关键词开始搜索")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("没有匹配「\(query)」的内容")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    SearchPage()
}
