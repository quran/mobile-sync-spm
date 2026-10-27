import Foundation
internal import Shared

/// A reading-bookmark slot, identified by its color.
public enum MobileSyncReadingBookmarkSlot: Hashable, Sendable {
  case teal
  case orange
  case red
}

/// The reading bookmark in one slot.
public struct MobileSyncReadingBookmark: Hashable, Sendable {
  public enum Placement: Hashable, Sendable {
    case ayah(sura: Int, ayah: Int)
    /// A page of `mushaf`, the mushaf the bookmarks were read in, numbered as ``MobileSyncMushaf`` describes.
    /// MobileSync maps a page set in another mushaf, here or on Quran.com, into it.
    case page(Int, mushaf: MobileSyncMushaf)
    /// A slot that doesn't point anywhere, a page bookmark the mushaf it was read in can't show, or a location set
    /// elsewhere that the app can't show (such as a surah or juz bookmark).
    case unplaced
  }

  public let id: String
  public let slot: MobileSyncReadingBookmarkSlot
  public let placement: Placement
  public let name: String?
  public let lastUpdated: Date

  public init(
    id: String,
    slot: MobileSyncReadingBookmarkSlot,
    placement: Placement,
    name: String?,
    lastUpdated: Date
  ) {
    self.id = id
    self.slot = slot
    self.placement = placement
    self.name = name
    self.lastUpdated = lastUpdated
  }
}

/// An ayah the user read.
public struct MobileSyncReadingSession: Hashable, Sendable {
  public let id: String
  public let sura: Int
  public let ayah: Int
  public let lastUpdated: Date

  public init(id: String, sura: Int, ayah: Int, lastUpdated: Date) {
    self.id = id
    self.sura = sura
    self.ayah = ayah
    self.lastUpdated = lastUpdated
  }
}

// MARK: - Kotlin mapping

extension MobileSyncReadingBookmarkSlot {
  /// Returns `nil` for a slot this package doesn't know yet.
  init?(_ slot: ReadingBookmarkSlot) {
    switch slot {
    case .teal: self = .teal
    case .orange: self = .orange
    case .red: self = .red
    default: return nil
    }
  }

  var kotlinSlot: ReadingBookmarkSlot {
    switch self {
    case .teal: .teal
    case .orange: .orange
    case .red: .red
    }
  }
}

extension MobileSyncReadingBookmark {
  /// Returns `nil` when the bookmark's slot, kind or mushaf is unknown.
  init?(_ bookmark: any ReadingBookmark) {
    let placement: Placement
    switch bookmark {
    case let bookmark as AyahReadingBookmark:
      placement = .ayah(sura: Int(bookmark.sura), ayah: Int(bookmark.ayah))
    case let bookmark as PageReadingBookmark:
      guard let mushaf = MobileSyncMushaf(bookmark.mushaf) else {
        return nil
      }
      placement = .page(Int(bookmark.page), mushaf: mushaf)
    case is EmptyReadingBookmark:
      placement = .unplaced
    default:
      return nil
    }
    guard let slot = MobileSyncReadingBookmarkSlot(bookmark.slot) else {
      return nil
    }
    self.init(
      id: bookmark.id,
      slot: slot,
      placement: placement,
      name: bookmark.name,
      lastUpdated: bookmark.lastUpdated
    )
  }
}

extension MobileSyncReadingSession {
  init(_ session: ReadingSession) {
    self.init(
      id: session.id,
      sura: Int(session.sura),
      ayah: Int(session.ayah),
      lastUpdated: session.lastUpdated
    )
  }
}
