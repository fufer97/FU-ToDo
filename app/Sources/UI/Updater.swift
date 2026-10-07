import Foundation
import SwiftUI
import Core

/// 检查更新：读取 GitHub Release 的版本号，和当前版本比较。
///
/// 说明（现实约束，写清楚免得误解）：
/// - 这在**公开**仓库上可以直接工作；仓库若是私有，未登录请求会得到 404，
///   界面会提示「无法访问」，而不是假装没有新版。
/// - 「自动下载并替换自身」需要稳定代码签名身份（Sparkle 的要求），
///   当前是 ad-hoc 签名，做不到；所以这里只做到「发现新版 + 打开下载页」。
@MainActor
public final class Updater: ObservableObject {
    /// 发布来源：本仓库（公开）。设置里「检查更新」就是读这里的 latest release。
    public static let repository = "fufer97/FU-ToDo"

    public enum Status: Equatable {
        case idle
        case checking
        case upToDate(String)
        case available(version: String, url: URL)
        case unreachable
        case failed(String)

        public var text: String {
            switch self {
            case .idle: return ""
            case .checking: return "正在检查…"
            case .upToDate(let version): return "已是最新版本（\(version)）"
            case .available(let version, _): return "有新版本 \(version)"
            case .unreachable: return "无法获取版本信息（仓库未公开或网络不通）"
            case .failed(let message): return "检查失败：\(message)"
            }
        }
    }

    @Published public private(set) var status: Status = .idle
    private var didAutoCheck = false

    public init() {}

    /// 启动时调用一次：只自动查一次，之后交给用户手动点。
    public func checkIfNeeded(auto: Bool) {
        guard auto, !didAutoCheck else { return }
        didAutoCheck = true
        _Concurrency.Task { await check() }
    }

    /// 比较版本号：把 "0.10" 与 "0.9" 这类按数字逐段比，而不是按字符串。
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                .split(separator: ".")
                .map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
        }
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    public func check() async {
        status = .checking
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest") else {
            status = .failed("地址无效")
            return
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                status = .failed("响应异常")
                return
            }
            switch http.statusCode {
            case 200:
                guard
                    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let tag = object["tag_name"] as? String
                else {
                    status = .failed("版本信息格式不对")
                    return
                }
                let page = (object["html_url"] as? String).flatMap(URL.init(string:))
                let version = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                if Self.isNewer(version, than: AppVersion.current), let page {
                    status = .available(version: version, url: page)
                } else {
                    status = .upToDate(AppVersion.current)
                }
            case 404, 403:
                // 私有仓库对未认证请求就是 404
                status = .unreachable
            default:
                status = .failed("HTTP \(http.statusCode)")
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
