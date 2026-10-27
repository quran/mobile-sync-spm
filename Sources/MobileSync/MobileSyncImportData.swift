import Foundation
internal import Shared

/// Local data to merge into MobileSync, such as data from an earlier app version.
public struct MobileSyncImportData: Hashable, Sendable {
  public let collections: [MobileSyncImportCollection]
  public let collectionBookmarks: [MobileSyncImportCollectionBookmark]
  public let readingSessions: [MobileSyncImportReadingSession]
  public let notes: [MobileSyncImportNote]
  public let highlights: [MobileSyncImportHighlight]
  public let readingBookmarks: [MobileSyncImportReadingBookmark]

  public init(
    collections: [MobileSyncImportCollection] = [],
    collectionBookmarks: [MobileSyncImportCollectionBookmark] = [],
    readingSessions: [MobileSyncImportReadingSession] = [],
    notes: [MobileSyncImportNote] = [],
    highlights: [MobileSyncImportHighlight] = [],
    readingBookmarks: [MobileSyncImportReadingBookmark] = []
  ) {
    self.collections = collections
    self.collectionBookmarks = collectionBookmarks
    self.readingSessions = readingSessions
    self.notes = notes
    self.highlights = highlights
    self.readingBookmarks = readingBookmarks
  }
}

public struct MobileSyncImportCollection: Hashable, Sendable {
  public let name: String
  public let lastUpdated: Date
  public let createdAt: Date?

  public init(name: String, lastUpdated: Date, createdAt: Date? = nil) {
    self.name = name
    self.lastUpdated = lastUpdated
    self.createdAt = createdAt
  }
}

/// An ayah bookmark to import into the collection with a matching name.
public struct MobileSyncImportCollectionBookmark: Hashable, Sendable {
  public let collectionName: String
  public let sura: Int
  public let ayah: Int
  public let lastUpdated: Date
  public let createdAt: Date?

  public init(collectionName: String, sura: Int, ayah: Int, lastUpdated: Date, createdAt: Date? = nil) {
    self.collectionName = collectionName
    self.sura = sura
    self.ayah = ayah
    self.lastUpdated = lastUpdated
    self.createdAt = createdAt
  }
}

public struct MobileSyncImportReadingSession: Hashable, Sendable {
  public let sura: Int
  public let ayah: Int
  public let lastUpdated: Date
  public let createdAt: Date?

  public init(sura: Int, ayah: Int, lastUpdated: Date, createdAt: Date? = nil) {
    self.sura = sura
    self.ayah = ayah
    self.lastUpdated = lastUpdated
    self.createdAt = createdAt
  }
}

public struct MobileSyncImportNote: Hashable, Sendable {
  public let body: String
  public let startSura: Int
  public let startAyah: Int
  public let endSura: Int
  public let endAyah: Int
  public let lastUpdated: Date
  public let createdAt: Date?

  public init(
    body: String,
    startSura: Int,
    startAyah: Int,
    endSura: Int,
    endAyah: Int,
    lastUpdated: Date,
    createdAt: Date? = nil
  ) {
    self.body = body
    self.startSura = startSura
    self.startAyah = startAyah
    self.endSura = endSura
    self.endAyah = endAyah
    self.lastUpdated = lastUpdated
    self.createdAt = createdAt
  }
}

public struct MobileSyncImportHighlight: Hashable, Sendable {
  public let sura: Int
  public let ayah: Int
  public let color: MobileSyncHighlightColor
  public let lastUpdated: Date
  public let createdAt: Date?

  public init(
    sura: Int,
    ayah: Int,
    color: MobileSyncHighlightColor,
    lastUpdated: Date,
    createdAt: Date? = nil
  ) {
    self.sura = sura
    self.ayah = ayah
    self.color = color
    self.lastUpdated = lastUpdated
    self.createdAt = createdAt
  }
}

public struct MobileSyncImportReadingBookmark: Hashable, Sendable {
  public enum Placement: Hashable, Sendable {
    case ayah(sura: Int, ayah: Int)
    /// A page of `mushaf`, numbered as ``MobileSyncMushaf`` describes. A page the mushaf doesn't have is skipped;
    /// with `deleteExisting: true`, its slot then ends up cleared, like a slot the import leaves out.
    case page(Int, mushaf: MobileSyncMushaf)
  }

  public let slot: MobileSyncReadingBookmarkSlot
  public let placement: Placement
  public let lastUpdated: Date
  public let name: String?

  public init(
    slot: MobileSyncReadingBookmarkSlot,
    placement: Placement,
    lastUpdated: Date,
    name: String? = nil
  ) {
    self.slot = slot
    self.placement = placement
    self.lastUpdated = lastUpdated
    self.name = name
  }
}

public struct MobileSyncImportResult: Hashable, Sendable {
  public let bookmarksImported: Int
  public let collectionsImported: Int
  public let collectionBookmarksImported: Int
  public let readingSessionsImported: Int
  public let notesImported: Int
  public let readingBookmarksImported: Int
  public let highlightsImported: Int
  public let readingSessionsUpdated: Int
  /// Items already present as equivalent data.
  public let matched: Int
  /// Items skipped to keep conflicting current data or another winning item.
  public let keptExisting: Int
  /// Items skipped because an earlier tracked import already handled them.
  public let alreadyProcessed: Int
  /// Whether the import changed synced user data; recording import history alone doesn't count.
  public let changed: Bool

  public init(
    bookmarksImported: Int = 0,
    collectionsImported: Int = 0,
    collectionBookmarksImported: Int = 0,
    readingSessionsImported: Int = 0,
    notesImported: Int = 0,
    readingBookmarksImported: Int = 0,
    highlightsImported: Int = 0,
    readingSessionsUpdated: Int = 0,
    matched: Int = 0,
    keptExisting: Int = 0,
    alreadyProcessed: Int = 0,
    changed: Bool = false
  ) {
    self.bookmarksImported = bookmarksImported
    self.collectionsImported = collectionsImported
    self.collectionBookmarksImported = collectionBookmarksImported
    self.readingSessionsImported = readingSessionsImported
    self.notesImported = notesImported
    self.readingBookmarksImported = readingBookmarksImported
    self.highlightsImported = highlightsImported
    self.readingSessionsUpdated = readingSessionsUpdated
    self.matched = matched
    self.keptExisting = keptExisting
    self.alreadyProcessed = alreadyProcessed
    self.changed = changed
  }
}

// MARK: - Kotlin mapping

extension MobileSyncImportData {
  var kotlinData: PersistenceImportData {
    PersistenceImportData(
      collections: collections.map {
        ImportCollection(name: $0.name, lastUpdated: $0.lastUpdated, createdAt: $0.createdAt)
      },
      collectionBookmarks: collectionBookmarks.map {
        ImportCollectionAyahBookmark(
          collectionName: $0.collectionName,
          sura: Int32($0.sura),
          ayah: Int32($0.ayah),
          lastUpdated: $0.lastUpdated,
          createdAt: $0.createdAt
        )
      },
      readingSessions: readingSessions.map {
        ImportReadingSession(
          sura: Int32($0.sura), ayah: Int32($0.ayah), lastUpdated: $0.lastUpdated, createdAt: $0.createdAt)
      },
      notes: notes.map {
        ImportNote(
          body: $0.body,
          startSura: Int32($0.startSura),
          startAyah: Int32($0.startAyah),
          endSura: Int32($0.endSura),
          endAyah: Int32($0.endAyah),
          lastUpdated: $0.lastUpdated,
          createdAt: $0.createdAt
        )
      },
      highlights: highlights.map {
        ImportAyahHighlight(
          sura: Int32($0.sura),
          ayah: Int32($0.ayah),
          color: $0.color.kotlinColor,
          lastUpdated: $0.lastUpdated,
          createdAt: $0.createdAt
        )
      },
      readingBookmarks: readingBookmarks.compactMap(\.kotlinBookmark)
    )
  }
}

extension MobileSyncImportReadingBookmark {
  /// `nil` for a page too large for MobileSync, which no mushaf has, so the import skips it.
  var kotlinBookmark: ImportReadingBookmark? {
    switch placement {
    case let .ayah(sura, ayah):
      ImportReadingBookmark.Ayah(
        sura: Int32(sura), ayah: Int32(ayah), lastUpdated: lastUpdated, slot: slot.kotlinSlot, name: name)
    case let .page(page, mushaf):
      Int32(exactly: page).map {
        ImportReadingBookmark.Page(
          page: $0, mushaf: mushaf.kotlinMushaf, lastUpdated: lastUpdated, slot: slot.kotlinSlot, name: name)
      }
    }
  }
}

extension MobileSyncImportResult {
  init(_ result: PersistenceImportResult) {
    self.init(
      bookmarksImported: Int(result.bookmarksImported),
      collectionsImported: Int(result.collectionsImported),
      collectionBookmarksImported: Int(result.collectionBookmarksImported),
      readingSessionsImported: Int(result.readingSessionsImported),
      notesImported: Int(result.notesImported),
      readingBookmarksImported: Int(result.readingBookmarksImported),
      highlightsImported: Int(result.highlightsImported),
      readingSessionsUpdated: Int(result.readingSessionsUpdated),
      matched: Int(result.matched),
      keptExisting: Int(result.keptExisting),
      alreadyProcessed: Int(result.alreadyProcessed),
      changed: result.changed
    )
  }
}
