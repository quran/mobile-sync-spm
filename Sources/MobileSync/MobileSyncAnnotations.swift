import Foundation
internal import Shared

public struct MobileSyncNote: Hashable, Sendable {
  public let id: String
  public let body: String
  /// Never empty. A note created in the app has one range; a note created on Quran.com may have several.
  public let ranges: [MobileSyncNoteRange]
  public let lastUpdated: Date

  public init(id: String, body: String, ranges: [MobileSyncNoteRange], lastUpdated: Date) {
    self.id = id
    self.body = body
    self.ranges = ranges
    self.lastUpdated = lastUpdated
  }
}

public struct MobileSyncNoteRange: Hashable, Sendable {
  public let startSura: Int
  public let startAyah: Int
  public let endSura: Int
  public let endAyah: Int

  public init(startSura: Int, startAyah: Int, endSura: Int, endAyah: Int) {
    self.startSura = startSura
    self.startAyah = startAyah
    self.endSura = endSura
    self.endAyah = endAyah
  }
}

public struct MobileSyncCollection: Hashable, Sendable {
  public let id: String
  public let name: String
  public let lastUpdated: Date
  public let isDefault: Bool
  /// Whether MobileSync manages this collection.
  public let isSystem: Bool
  /// Whether users can't rename or delete it: system collections, and the color collections older Quran.com
  /// apps created, which the server protects.
  public let isReadOnly: Bool

  public init(id: String, name: String, lastUpdated: Date, isDefault: Bool, isSystem: Bool, isReadOnly: Bool) {
    self.id = id
    self.name = name
    self.lastUpdated = lastUpdated
    self.isDefault = isDefault
    self.isSystem = isSystem
    self.isReadOnly = isReadOnly
  }
}

/// An ayah bookmark's membership in a collection.
public struct MobileSyncCollectionBookmark: Hashable, Sendable {
  public let collectionID: String
  public let bookmarkID: String
  public let sura: Int
  public let ayah: Int
  /// When the bookmark itself last changed, not the collection or this membership.
  public let bookmarkLastUpdated: Date
  /// When the bookmark itself was created, not the collection or this membership.
  public let bookmarkAddedDate: Date

  public init(
    collectionID: String,
    bookmarkID: String,
    sura: Int,
    ayah: Int,
    bookmarkLastUpdated: Date,
    bookmarkAddedDate: Date
  ) {
    self.collectionID = collectionID
    self.bookmarkID = bookmarkID
    self.sura = sura
    self.ayah = ayah
    self.bookmarkLastUpdated = bookmarkLastUpdated
    self.bookmarkAddedDate = bookmarkAddedDate
  }
}

public struct MobileSyncCollectionWithBookmarks: Hashable, Sendable {
  public let collection: MobileSyncCollection
  public let bookmarks: [MobileSyncCollectionBookmark]

  public init(collection: MobileSyncCollection, bookmarks: [MobileSyncCollectionBookmark]) {
    self.collection = collection
    self.bookmarks = bookmarks
  }
}

public enum MobileSyncHighlightColor: Hashable, Sendable {
  case blue
  case pink
  case green
  case yellow
  case purple
}

public struct MobileSyncAyahHighlight: Hashable, Sendable {
  public let sura: Int
  public let ayah: Int
  public let color: MobileSyncHighlightColor
  public let lastUpdated: Date

  public init(sura: Int, ayah: Int, color: MobileSyncHighlightColor, lastUpdated: Date) {
    self.sura = sura
    self.ayah = ayah
    self.color = color
    self.lastUpdated = lastUpdated
  }
}

// MARK: - Kotlin mapping

extension MobileSyncNote {
  init(_ note: Note) {
    self.init(
      id: note.id,
      body: note.body,
      ranges: note.ranges.map(MobileSyncNoteRange.init),
      lastUpdated: note.lastUpdated
    )
  }
}

extension MobileSyncNoteRange {
  init(_ range: NoteRange) {
    self.init(
      startSura: Int(range.startSura),
      startAyah: Int(range.startAyah),
      endSura: Int(range.endSura),
      endAyah: Int(range.endAyah)
    )
  }
}

extension MobileSyncCollection {
  init(_ collection: BookmarkCollection) {
    self.init(
      id: collection.id,
      name: collection.name,
      lastUpdated: collection.lastUpdated,
      isDefault: collection.isDefault,
      isSystem: collection.isSystem,
      isReadOnly: collection.isReadOnly
    )
  }
}

extension MobileSyncCollectionBookmark {
  init(_ bookmark: CollectionAyahBookmark) {
    self.init(
      collectionID: bookmark.collectionId,
      bookmarkID: bookmark.bookmarkId,
      sura: Int(bookmark.sura),
      ayah: Int(bookmark.ayah),
      bookmarkLastUpdated: bookmark.bookmarkLastUpdated,
      bookmarkAddedDate: bookmark.bookmarkAddedDate
    )
  }
}

extension MobileSyncCollectionWithBookmarks {
  init(_ collection: CollectionWithAyahBookmarks) {
    self.init(
      collection: MobileSyncCollection(collection.collection),
      bookmarks: collection.bookmarks.map(MobileSyncCollectionBookmark.init)
    )
  }
}

extension MobileSyncHighlightColor {
  /// Returns `nil` for a color this package doesn't know yet.
  init?(_ color: AyahHighlightColor) {
    switch color {
    case .blue: self = .blue
    case .pink: self = .pink
    case .green: self = .green
    case .yellow: self = .yellow
    case .purple: self = .purple
    default: return nil
    }
  }

  var kotlinColor: AyahHighlightColor {
    switch self {
    case .blue: .blue
    case .pink: .pink
    case .green: .green
    case .yellow: .yellow
    case .purple: .purple
    }
  }
}

extension MobileSyncAyahHighlight {
  /// Returns `nil` when the highlight's color is unknown.
  init?(_ highlight: AyahHighlight) {
    guard let color = MobileSyncHighlightColor(highlight.color) else {
      return nil
    }
    self.init(
      sura: Int(highlight.sura),
      ayah: Int(highlight.ayah),
      color: color,
      lastUpdated: highlight.lastUpdated
    )
  }
}
