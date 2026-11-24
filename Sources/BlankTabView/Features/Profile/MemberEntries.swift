import Foundation
import SwiftUI

/// 「我的」页与成员详情共用的四个入口：可点条件与目标页统一在这里，避免两处各写一套。
enum MemberEntries {
    /// 周榜 / 月榜：需要榜单链接，且对应排名已拿到。
    static func rank(_ metrics: MemberMetrics, monthly: Bool) -> ProfileDestination? {
        guard !metrics.rankScheme.isEmpty, !metrics.member.itemId.isEmpty else { return nil }
        let position = monthly ? metrics.monthRank : metrics.weekRank
        guard position != nil else { return nil }
        return .rank(
            memberId: metrics.member.itemId,
            scheme: metrics.rankScheme,
            title: monthly ? metrics.monthTitle : metrics.weekTitle,
            tabName: monthly ? metrics.monthTabName : metrics.weekTabName
        )
    }

    /// 乐迷皮肤：需要拿得到乐迷勋章（medal_id）。
    static func skins(_ metrics: MemberMetrics) -> ProfileDestination? {
        guard metrics.hasSkinMedal, !metrics.member.itemId.isEmpty else { return nil }
        return .skins(
            memberId: metrics.member.itemId,
            medalId: metrics.skinMedalId,
            medalName: metrics.skinMedalName,
            scheme: metrics.skinMedalScheme
        )
    }

    /// 已获得奖章：恒可点。
    static func medals(_ metrics: MemberMetrics) -> ProfileDestination? {
        guard !metrics.member.itemId.isEmpty else { return nil }
        return .medalHall(memberId: metrics.member.itemId)
    }

    /// 家族格：恒可点。
    static func family(_ family: Family) -> ProfileDestination {
        .family(family)
    }

    static func weekTitle(_ metrics: MemberMetrics) -> String {
        Fmt.cleanTabName(metrics.weekTabName).isEmpty ? "周榜" : Fmt.cleanTabName(metrics.weekTabName)
    }

    static func monthTitle(_ metrics: MemberMetrics) -> String {
        Fmt.cleanTabName(metrics.monthTabName).isEmpty ? "月榜" : Fmt.cleanTabName(metrics.monthTabName)
    }
}
