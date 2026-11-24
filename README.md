# 三页 · TabView 空白示例

SwiftUI 最小工程：`TabView` 三个空白页（首页、我的、搜索），不包含 App 图标资源。用 **Xcode 27.2 / iOS 27.2 SDK** 构建。

| Tab | 页面文件 | 说明 |
| --- | --- | --- |
| 首页 | `Sources/BlankTabView/Pages/HomePage.swift` | 空白 |
| 我的 | `Sources/BlankTabView/Pages/ProfilePage.swift` | 空白 |
| 搜索 | `Sources/BlankTabView/Pages/SearchPage.swift` | 空白 |

Tab 的定义集中在 `AppTab.swift`（标题、SF Symbol、顺序），`RootTabView.swift` 用 `Tab(title:systemImage:value:)` 把它们挂进 `TabView`。

## 构建

CI 由 [ios-ci-workflows](https://github.com/wenjinliuu/ios-ci-workflows) 的约定驱动：`.ios-ci.yml` 是唯一配置源，`.github/workflows/build-test.yml` 是薄入口，具体命令在 `ci/build.sh`。

- runner：`xcode-27`（macOS 27 + Xcode 27.2，Apple Silicon）
- 工具链：`/Applications/Xcode_27.2.app`，iOS 27.2 SDK，模拟器 iPhone 18 Pro (iOS 27.2)
- 工程：XcodeGen 2.46.0 生成 `BlankTabView.xcodeproj`（`.xcodeproj` 不提交）
- 产物：Release、**无签名** `BlankTabView-unsigned.ipa`，上传到 Actions artifact `unsigned-ipa` 与 Release `unsigned-ipa`（构建日志在 Release `ci-logs`）

本地不需要 Mac；改代码 push 后读 Actions 的 Build & Test 报告。

> 与中央可复用工作流的差异：中央 test job 固定在 `macos-26`，而 Xcode 27.2 只装在 `xcode-27` 镜像（macOS 27）里，所以本仓库在 `ci/build.sh` 就地实现 Build & Test，仍以 `.ios-ci.yml` 为唯一配置源。

## 结构

```
.ios-ci.yml                      # ios-ci-workflows 配置（xcode 27.2 / ios 27.2）
project.yml                      # XcodeGen 工程描述
ci/build.sh                      # 选 Xcode、生成、测试、无签名归档、打包 IPA
Sources/BlankTabView/
  App/                           # 入口、AppTab、RootTabView
  Pages/                         # 首页 / 我的 / 搜索
Tests/BlankTabViewTests/         # AppTab 的单元测试
```

## 说明

- 不添加 App 图标：工程里没有 `Assets.xcassets`/`.icon`，跑出来的 IPA 使用系统默认图标。
- 无签名 IPA 只能用于越狱设备、模拟器侧安装或重签名后使用，不能直接装到未越狱真机。
