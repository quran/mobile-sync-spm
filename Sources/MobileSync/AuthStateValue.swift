import Shared

public enum AuthStateValue {
  case idle
  case loading
  case success(UserInfo?)
  case error(exception: KotlinException?, message: String)

  public init(_ state: AuthState) {
    switch state {
    case is AuthState.Idle:
      self = .idle
    case is AuthState.Loading:
      self = .loading
    case let success as AuthState.Success:
      self = .success(success.userInfo)
    case let error as AuthState.Error:
      self = .error(exception: error.exception as? KotlinException, message: error.message)
    default:
      fatalError("Unhandled AuthState subtype: \(type(of: state))")
    }
  }
}

public extension AuthService {
  var authStateValue: AuthStateValue {
    AuthStateValue(authState)
  }

  var loggedInUser: UserInfo? {
    switch authStateValue {
    case let .success(user):
      user
    case .idle, .loading, .error:
      nil
    }
  }
}
