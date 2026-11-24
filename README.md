# 三页 · TabView 示例（含「我的」页业务逻辑与详情页）

SwiftUI 工程：`TabView` 三页（首页、我的、搜索），每页顶部左侧显示标题；「我的」页标题下方是一个带圆形凸起的**异形圆角卡片**（无阴影，用底色与留白做层次）。不包含 App 图标资源。用 **Xcode 27.2 / iOS 27.2 SDK** 构建。

| Tab | 页面文件 | 内容 |
| --- | --- | --- |
| 首页 | `Pages/HomePage.swift` | 左上角标题“首页”，其余空白 |
| 我的 | `Pages/ProfilePage.swift` | 左上角标题“我的” + 成员票据卡 + 近 7 天荣誉图表 + 荣誉记录，票据卡四项数据与家族格可点进详情 |
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
| 本地持久化（键名与旧版一致，含旧数据迁移、皮肤缓存） | `Data/AppStore.swift` |
| QQ 音乐签名（SHA1 + 异或 + base64 三段拼接） | `Data/QqSign.swift` |
| 统一 HTTP 出口（UA / Referer / 超时 / 错误文案） | `Data/QqHttp.swift` |
| 接口层（家族成员、勋章馆 SSR、排行榜、勋章详情、皮肤） | `Data/QqApi.swift` |
| 模块分页与皮肤序列扫描（`GetModuleDetail`、`skin_detail.html`） | `Data/QqMedalExtra.swift` |
| 家族仓库（链接归一化、页面解析、成员拉取与归属） | `Data/FamilyRepository.swift` |
| 荣誉仓库（按日分组、近 7 天合计、HAR 导入） | `Data/HonorRepository.swift` |
| 勋章仓库（5 分钟缓存 + in-flight 去重 + Tab 并行补齐 + 皮肤渐进扫描） | `Data/MedalRepository.swift` |
| 成员指标服务（周榜 / 月榜 / 皮肤 / 奖章 / 乐迷值） | `Data/MemberMetricsService.swift` |
| 装配入口、成员快照与页面链接 | `Data/AppServices.swift`、`Data/ServiceLookup.swift` |
| 页面状态机 / 票据卡 / 图表与记录 / 设置页 | `Features/Profile/` |

行为对齐 Flutter 版：选中成员变化时清空并重拉；无成员直接结束；已读缓存优先，`force` 绕过；`_openSettings` 保存后 `invalidate()` 再强制重拉；家族本周荣誉优先用成员荣誉汇总，否则回退家族页 `weekHonor`；勋章馆 / 排行榜 / 皮肤均带 TTL 缓存与去重。

## 详情页（从票据卡点进去）

票据卡四个入口与家族格全部可点，可点条件与 Flutter 版一致（周/月需 `rankScheme` 非空且排名非 nil、皮肤需拿得到乐迷勋章、奖章恒可点、家族格恒可点）。路由集中在 `ProfileDestination.swift`，由 `ProfilePage` 的 `NavigationStack(path:)` + `navigationDestination` 分发：

| 入口 | 页面 | 业务逻辑 |
| --- | --- | --- |
| 周榜 / 月榜 | `Features/Detail/RankDetailView.swift` | `rankPage(scheme)` → 按 tabName 精确/包含定位 Tab，未命中则 `rankTab` 懒加载；单 Tab 隐藏胶囊；行显示名次/头像/铭牌/描述/点赞，`isMe` 显示“我” |
| 已获得奖章 | `Features/Detail/MedalsHallView.swift` | 先出 SSR 首屏，再并行补齐其余 Tab（完成一个刷一次）；模块卡前 3 枚勋章，模块可进全部列表，勋章点开 sheet；乐迷 Tab 的勋章改走皮肤页 |
| 模块全部 | `Features/Detail/MedalModuleView.swift` | `modulePage` 首屏 50，`lastPos` 非空且 `HasNext` 时按 21 追加 |
| 乐迷皮肤 | `Features/Detail/SkinsView.swift` | 先读本地皮肤缓存，再 `scanSkins` 逐批（20 并发、100 一档、连续 100 空位或超过 2000 停、先拿总数凑齐即停）；按 `categId` 分组、`other` 置末、组内按 `seq` |
| 皮肤系列 | `Features/Detail/SkinSeriesView.swift` | 系列内全部皮肤网格，点开单皮肤 sheet |
| 皮肤详情 | `Features/Detail/SkinDetailSheet.swift` | 大图用 `BGColor` 作底；序号/分类/解锁状态/限定编号/获取日期/全服解锁人数/解锁条件；复制皮肤链接 |
| 勋章详情 | `Features/Detail/MedalDetailSheet.swift` | `detail(medalId)` → 只留 `picUrl` 非空的等级，优先精确匹配 `medalId`，按 level 升序，多张可左右翻页，日期取 `createTime` |
| 家族格 | `Features/Detail/FamilyDetailView.swift` | 成员 30s 超时拉取，失败回退本地缓存；家族资料卡（成员数可进列表）+ 本周/上周总荣誉与近 7 天柱状图 + 成员前 5 + 不达标（荣誉 < 500，默认 3 行可展开） |
| 成员数 / 查看全部 | `Features/Detail/MemberListView.swift` | 家族名 + “成员列表 · 共 N 人” + 全部成员行（铭牌/乐迷牌/荣誉/ID） |
| 成员行 | `Features/Detail/MemberDetailView.swift` | `metrics.load(force: true)` 45s + 荣誉分组；失败时用缓存成员资料卡 + 错误卡，成功时复用图表与记录 |

详情页同样零阴影，卡片用 `Components/ProfileKit.swift` 的 `InfoCard`（统一圆角 + 底色）。

## 构建

CI 由 [ios-ci-workflows](https://github.com/wenjinliuu/ios-ci-workflows) 的约定驱动：`.ios-ci.yml` 是唯一配置源，`.github/workflows/build-test.yml` 是薄入口，具体命令在 `ci/build.sh`。

- runner：`xcode-27`（macOS 27 + Xcode 27.2，Apple Silicon）
- 工具链：`/Applications/Xcode_27.2.app`，iOS 27.2 SDK，模拟器 iPhone 18 Pro (iOS 27.2)
- 工程：XcodeGen 2.46.0 生成 `BlankTabView.xcodeproj`（`.xcodeproj` 不提交）
- 产物：Release、**无签名** `BlankTabView-unsigned.ipa`，上传到 Actions artifact `unsigned-ipa` 与 Release `unsigned-ipa`（构建日志在 Release `ci-logs`）
- 测试：32 个单测覆盖签名单测参考值、家族链接归一化、格式化、SSR 解析、模型展示值、荣誉分组与每日合计、皮肤缓存与模块解析

本地不需要 Mac；改代码 push 后读 Actions 的 Build & Test 报告。

> 与中央可复用工作流的差异：中央 test job 固定在 `macos-26`，而 Xcode 27.2 只装在 `xcode-27` 镜像（macOS 27）里，所以本仓库在 `ci/build.sh` 就地实现 Build & Test，仍以 `.ios-ci.yml` 为唯一配置源。

## 结构

```
.ios-ci.yml                      # ios-ci-workflows 配置（xcode 27.2 / ios 27.2）
project.yml                      # XcodeGen 工程描述
ci/build.sh                      # 选 Xcode、生成、测试、无签名归档、打包 IPA
Sources/BlankTabView/
  App/                           # 入口、AppTab、RootTabView
  Components/                    # PageTitle、PageScaffold、ProfileCard、ProfileKit
  Data/                          # 模型、存储、签名、HTTP、接口、仓库、指标服务
  Features/Profile/              # 状态机、票据卡、图表与记录、设置页、路由
  Features/Detail/               # 排行榜、勋章馆、模块、皮肤（含系列与 sheet）、家族、成员
  Pages/                         # 首页 / 我的 / 搜索
Tests/BlankTabViewTests/         # 卡片几何、签名、链接、格式化、SSR、荣誉、模型、详情层
```

## 说明

- 不添加 App 图标：工程里没有 `Assets.xcassets`/`.icon`，跑出来的 IPA 使用系统默认图标。
- 「我的」页与详情页的真实数据需要 QQ 音乐登录态（家族链接 + 成员 enc_uin）；CI 只保证编译与单测，不联网联调。
- 家族详情里的 HAR 导入与分享图、成员详情里的巅峰制作人/乐迷灯牌/星光发电站、荣誉记录页不在本次详情页范围内，可直接复用现有仓库层后续补上。
- 无签名 IPA 只能用于越狱设备、模拟器侧安装或重签名后使用，不能直接装到未越狱真机。
