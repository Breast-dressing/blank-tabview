import Foundation

/// 唯一装配入口：所有能力在这里接线，UI 只依赖 AppServices.shared。
final class AppServices: @unchecked Sendable {
    static let shared = AppServices()

    let store: AppStore
    let http: QqHttp
    let api: QqApi
    let families: FamilyRepository
    let honors: HonorRepository
    let medals: MedalRepository
    let metrics: MemberMetricsService

    private init() {
        let store = AppStore.open()
        let http = QqHttp()
        let api = QqApi(http: http)
        let families = FamilyRepository(store: store, api: api)
        let honors = HonorRepository(store: store)
        let medals = MedalRepository(store: store, api: api)
        let metrics = MemberMetricsService(
            store: store,
            api: api,
            families: families,
            honors: honors,
            medals: medals
        )

        self.store = store
        self.http = http
        self.api = api
        self.families = families
        self.honors = honors
        self.medals = medals
        self.metrics = metrics
    }
}
