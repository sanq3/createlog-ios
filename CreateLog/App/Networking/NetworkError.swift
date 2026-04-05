import Foundation

/// アプリ全体で使う統一エラー型
enum NetworkError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case serverError(statusCode: Int, message: String)
    case decodingError(String)
    case networkUnavailable
    case timeout
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "ログインが必要です"
        case .serverError(let code, let message):
            "サーバーエラー (\(code)): \(message)"
        case .decodingError(let detail):
            "データの読み込みに失敗しました: \(detail)"
        case .networkUnavailable:
            "ネットワークに接続できません"
        case .timeout:
            "通信がタイムアウトしました"
        case .unknown(let message):
            message
        }
    }
}
