//
//  ShimExports.swift
//  MobileSyncSPM
//
//  Created by Ahmed El-Helw on 11/1/25.
//

@_exported import Shared

/// Swift-friendly name for the KMP collection model.
///
/// Kotlin/Native exports the upstream `Collection` model as `Collection_` because
/// `Collection` collides with Swift's standard-library protocol.
public typealias BookmarkCollection = Collection_
