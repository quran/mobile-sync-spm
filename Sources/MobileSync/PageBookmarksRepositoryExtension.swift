//
//  PageBookmarksRepositoryExtension.swift
//  Shared
//
//  Created by Ahmed El-Helw on 11/1/25.
//

import Foundation
import KMPNativeCoroutinesAsync
import Shared

public extension PageBookmarksRepository {
  func bookmarksSequence() -> NativeFlowAsyncSequence<[PageBookmark], Error, KotlinUnit> {
    asyncSequence(for: getAllBookmarks())
  }
}
