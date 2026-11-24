# 三页 · TabView 示例（含「我的」页业务逻辑）

SwiftUI 工程：`TabView` 三页（首页、我的、搜索），每页顶部左侧显示标题；「我的」页标题下方是一个带圆形凸起的**异形圆角卡片**（无阴影，用底色与留白做层次）。不包含 App 图标资源。用 **Xcode 27.2 / iOS 27.2 SDK** 构建。

| Tab | 页面文件 | 内容 |
| --- | --- | --- |
| 首页 | `Pages/HomePage.swift` | 左上角标题“首页”，其余空白 |
| 我的 | `Pages/ProfilePage.swift` | 左上角标题“我的” + 成员票据卡 + 近 7 天荣誉图表 + 荣誉记录 |
| 搜索 | `Pages/SearchPage.swift` | 左上角标题“搜索”，其余空白 |

- 标题统一由 `Components/PageTitle.swift` 渲染，页面骨架 `Components/PageScaffold.swift` 负责左上对齐、背景与可选滚动（`scroll: true`）。
- 异形圆角卡片在 `Components/ProfileCard.swift`：`RoundedRectangle(cornerRadius: 28)` 与左上角一个圆形凸起同色填充、`compositingGroup()` 合成一个连续轮廓，凸起内放头像。几何参数集中在 `ProfileCardMetrics`。
- Tab 定义集中在 `AppTab.swift`（标题、SF Symbol、顺序），`RootTabView.swift` 用 `Tab(title:systemImage:value:)` 挂进 `TabView`。

## 「我的」页逻辑（从 Flutter 版全量搬迁）

UI 完全用原生 SwiftUI 重做（不使用 Flutter 的布局与组件），但数据处理链路的每一步都搬过来了：

| 能力 | 文件 |
| --- | --- |
| 数据模型（Family / Member / 勋章 / 荣誉 / 指标） | `Data/Models.swift` |
| 数字 / 日期 / 文本格式化（千分位、日期 key、tab 名清洗） | `Data/Fmt.swift` |
| 本地持久化（键名与旧版一致，含旧数据迁移） | `Data/AppStore.swift` |
| QQ 音乐签名（SHA1 + 异或 + base64 三段拼接） | `Data/QqSign.swift` |
| 统一 HTTP 出口（UA / Referer / 超时 / 错误文案） | `Data/QqHttp.swift` |
| 接口层（家族成员、勋章馆 SSR、排行榜、勋章详情、皮肤） | `Data/QqApi.swift` |
| 家族仓库（链接归一化、页面解析、成员拉取与归属） | `Data/FamilyRepository.swift` |
| 荣誉仓库（按日分组、近 7 天合计、HAR 导入） | `Data/HonorRepository.swift` |
| 勋章仓库（5 分钟缓存 + in-flight 去重） | `Data/MedalRepository.swift` |
| 成员指标服务（周榜 / 月榜 / 皮肤 / 奖章 / 乐迷值） | `Data/MemberMetricsService.swift` |
| 装配入口 | `Data/AppServices.swift` |
| 页面状态机 / 票据卡 / 图表与记录 / 设置页 | `Features/Profile/` |

行为对齐 Flutter 版：选中成员变化时清空并重拉；无成员直接结束；已读缓存优先，`force` 绕过；`_openSettings` 保存后 `invalidate()` 再强制重拉；家族本周荣誉优先用成员荣誉汇总，否则回退家族页 `weekHonor`；勋章馆 / 排行榜 / 皮肤均带 TTL 缓存与去重。

## 构建

CI 由 [ios-ci-workflows](https://github.com/wenjinliuu/ios-ci-workflows) 的约定驱动：`.ios-ci.yml` 是唯一配置源，`.github/workflows/build-test.yml` 是薄入口，具体命令在 `ci/build.sh`。

- runner：`xcode-27`（macOS 27 + Xcode 27.2，Apple Silicon）
- 工具链：`/Applications/Xcode_27.2.app`，iOS 27.2 SDK，模拟器 iPhone 18 Pro (iOS 27.2)
- 工程：XcodeGen 2.46.0 生成 `BlankTabView.xcodeproj`（`.xcodeproj` 不提交）
- 产物：Release、**无签名** `BlankTabView-unsigned.ipa`，上传到 Actions artifact `unsigned-ipa` 与 Release `unsigned-ipa`（构建日志在 Release `ci-logs`）
- 测试：27 个单测覆盖签名单测参考值、家族链接归一化、格式化、SSR 解析、模型展示值、荣誉分组与每日合计

本地不需要 Mac；改代码 push 后读 Actions 的 Build & Test 报告。

> 与中央可复用工作流的差异：中央 test job 固定在 `macos-26`，而 Xcode 27.2 只装在 `xcode-27` 镜像（macOS 27）里，所以本仓库在 `ci/build.sh` 就地实现 Build & Test，仍以 `.ios-ci.yml` 为唯一配置源。

## 结构

```
.ios-ci.yml                      # ios-ci-workflows 配置（xcode 27.2 / ios 27.2）
project.yml                      # XcodeGen 工程描述
ci/build.sh                      # 选 Xcode、生成、测试、无签名归档、打包 IPA
Sources/BlankTabView/
  App/                           # 入口、AppTab、RootTabView
  Components/                    # PageTitle、PageScaffold、ProfileCard
  Data/                          # 模型、存储、签名、HTTP、接口、仓库、指标服务
  Features/Profile/              # 状态机、票据卡、图表与记录、设置页
  Pages/                         # 首页 / 我的 / 搜索
Tests/BlankTabViewTests/         # 卡片几何、签名、链接、格式化、SSR、荣誉、模型
```

## 说明

- 不添加 App 图标：工程里没有 `Assets.xcassets`/`.icon`，跑出来的 IPA 使用系统默认图标。
- 「我的」页真实数据需要 QQ 音乐登录态（家族链接 + 成员 enc_uin）；CI 只保证编译与单测，不联网联调。
- 无签名 IPA 只能用于越狱设备、模拟器侧安装或重签名后使用，不能直接装到未越狱真机。
