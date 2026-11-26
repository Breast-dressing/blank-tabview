import Foundation

extension MedalItem {
    /// 分级勋章（同一家族有 1…N 级）只要有一级已解锁就不该算「待解锁」：
    /// 接口给的卡上 Level 是当前已达等级（一级都没有时为 0），State == 2 表示确实已获得。
    var attained: Bool {
        state == 2 || level >= 1
    }

    /// 卡面第二行：已获得显示编号 / 日期，未获得显示「待解锁」。
    var tileSubtitle: String {
        attained ? subtitle : "待解锁"
    }
}
