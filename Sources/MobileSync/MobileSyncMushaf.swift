import Foundation
internal import Shared

/// A page layout apps show the Quran in, and set and read page reading bookmarks in. MobileSync maps pages
/// between them.
public enum MobileSyncMushaf: Hashable, Sendable {
  /// The 1405 AH Madani print, 604 pages.
  case madani1405
  /// The newer (1440) Madani print, 604 pages.
  case madani1440
  /// The 15-line IndoPak print. Pages are numbered as the apps number them, 2…611, where page 1 is the cover.
  case indopak15Lines
  /// The Shemerly print, 521 pages.
  /// Quran.com has no Shemerly mushaf yet, so a page syncs as the ``madani1440`` page holding the same verses.
  case shemerly
  /// The Warsh riwayah, 604 pages. Its pages map to no other mushaf: a page set here reads as
  /// ``MobileSyncReadingBookmark/Placement/unplaced`` in any other.
  /// Today's Quran.com backend rejects it, so its changes are held (``MobileSyncHeldReason/rejectedByServer``).
  case warsh
  /// The Qaloun riwayah, 604 pages. Its pages map to no other mushaf, like ``warsh``.
  /// Today's Quran.com backend rejects it, so its changes are held (``MobileSyncHeldReason/rejectedByServer``).
  case qaloun
}

// MARK: - Kotlin mapping

extension MobileSyncMushaf {
  /// Returns `nil` for a mushaf this package doesn't know yet.
  init?(_ mushaf: Mushaf) {
    switch mushaf {
    case .madani1405: self = .madani1405
    case .madani1440: self = .madani1440
    case .indopak15Lines: self = .indopak15Lines
    case .shemerly: self = .shemerly
    case .warsh: self = .warsh
    case .qaloun: self = .qaloun
    default: return nil
    }
  }

  var kotlinMushaf: Mushaf {
    switch self {
    case .madani1405: .madani1405
    case .madani1440: .madani1440
    case .indopak15Lines: .indopak15Lines
    case .shemerly: .shemerly
    case .warsh: .warsh
    case .qaloun: .qaloun
    }
  }
}
