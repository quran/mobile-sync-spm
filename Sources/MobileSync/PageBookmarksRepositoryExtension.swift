//
//  PageBookmarksRepositoryExtension.swift
//  Shared
//
//  Created by Ahmed El-Helw on 11/1/25.
//

import Foundation
import KMPNativeCoroutinesAsync
import Shared

public extension BookmarksRepository {
  func bookmarksSequence() -> NativeFlowAsyncSequence<[Bookmark], Error, KotlinUnit> {
    asyncSequence(for: getBookmarksFlow())
  }
}
