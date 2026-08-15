import Foundation

/// Why a turn ended badly. Messages are user-facing Vietnamese: the chat shows
/// them on the failed session and offers a resend, it never retries silently.
public enum EngineError: Error, Equatable, LocalizedError, Sendable {
    /// The process could not be started at all.
    case launchFailed(String)
    /// KTD1 watchdog: no new event for longer than the silence threshold.
    case hung(silence: TimeInterval)
    /// The engine finished with `result.is_error == true`.
    case failed(message: String)
    /// The process died without ever emitting a terminal `result`.
    case exited(code: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let reason):
            "Không chạy được Claude Code: \(reason)"
        case .hung(let silence):
            "Engine treo — không có phản hồi mới trong \(Self.duration(silence)). Đã dừng phiên, gửi lại khi sẵn sàng."
        case .failed(let message):
            message.isEmpty ? "Engine báo lỗi, không rõ nguyên nhân." : message
        case .exited(let code, let message):
            message.isEmpty
                ? "Engine thoát bất thường (mã \(code))." : "Engine thoát bất thường (mã \(code)): \(message)"
        }
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        seconds >= 60
            ? "\(Int((seconds / 60).rounded())) phút"
            : "\(Int(seconds.rounded())) giây"
    }
}
