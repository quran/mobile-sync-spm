import Foundation
internal import Shared

/// The signed-in user's Quran.com profile.
public struct MobileSyncUser: Hashable, Sendable {
  public let id: String
  public let firstName: String?
  public let lastName: String?
  public let name: String?
  public let email: String?
  public let photoURL: String?

  public init(
    id: String,
    firstName: String? = nil,
    lastName: String? = nil,
    name: String? = nil,
    email: String? = nil,
    photoURL: String? = nil
  ) {
    self.id = id
    self.firstName = firstName
    self.lastName = lastName
    self.name = name
    self.email = email
    self.photoURL = photoURL
  }
}

// MARK: - Kotlin mapping

extension MobileSyncUser {
  init(_ user: UserInfo) {
    self.init(
      id: user.id,
      firstName: user.firstName,
      lastName: user.lastName,
      name: user.name,
      email: user.email,
      photoURL: user.photoUrl
    )
  }
}
