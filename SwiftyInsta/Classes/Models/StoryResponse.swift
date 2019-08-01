//
//  StoryResponse.swift
//  SwiftyInsta
//
//  Created by Stefano Bertagno on 02/08/2019.
//  Copyright © 2019 Mahdi. All rights reserved.
//

import Foundation

/// A `Tray` response.
public struct Tray: ParsedResponse {
    /// The `rawResponse`.
    public let rawResponse: DynamicResponse
    /// Init with `rawResponse`.
    public init(rawResponse: DynamicResponse) { self.rawResponse = rawResponse }

    /// The actual `TrayElement`s.
    var items: [TrayElement] {
        return rawResponse.tray.array?.compactMap { TrayElement(rawResponse: $0) } ?? []
    }
}

/// A `TrayElement` response.
public struct TrayElement: IdentifiableParsedResponse {
    /// The `rawResponse`.
    public let rawResponse: DynamicResponse
    /// Init with `rawResponse`.
    public init(rawResponse: DynamicResponse) { self.rawResponse = rawResponse }

    /// The `identity`.
    public var identity: Identifier<TrayElement> { .init(identifier: rawResponse.id.string ?? "") }
    /// The `lastSeenOnDate`.
    public var lastSeenOn: Date {
        rawResponse.seen
            .double
            .flatMap { $0 > 9_999_999_999 ? $0/1_000 : $0 }
            .flatMap { Date(timeIntervalSince1970: $0) } ?? .distantPast
    }
    /// The `expiringAtDate`.
    public var expiringAt: Date {
        rawResponse.expiringAt
            .double
            .flatMap { $0 > 9_999_999_999 ? $0/1_000 : $0 }
            .flatMap { Date(timeIntervalSince1970: $0) } ?? .distantPast
    }
    /// The actual `TrayMedia`.
    var media: [TrayMedia] {
        rawResponse.items.array?.compactMap { TrayMedia(rawResponse: $0) } ?? []
    }
}

/// A `TrayMedia` response.
public struct TrayMedia: IdentifiableParsedResponse {
    /// The `rawResponse`.
    public let rawResponse: DynamicResponse
    /// Init with `rawResponse`.
    public init(rawResponse: DynamicResponse) { self.rawResponse = rawResponse }

    /// The `identity`.
    public var identity: Identifier<TrayMedia> {
        .init(primaryKey: rawResponse.pk.int ?? rawResponse.pk.string.flatMap(Int.init),
              identifier: rawResponse.id.string ?? "")
    }
    /// The `takenAtDate`.
    public var takenAt: Date {
        rawResponse.takenAt
            .double
            .flatMap { $0 > 9_999_999_999 ? $0/1_000 : $0 }
            .flatMap { Date(timeIntervalSince1970: $0) } ?? .distantPast
    }
    /// The `expiringAt`.
    public var expiringAt: Date {
        rawResponse.expiringAt
            .double
            .flatMap { $0 > 9_999_999_999 ? $0/1_000 : $0 }
            .flatMap { Date(timeIntervalSince1970: $0) } ?? .distantPast
    }
    /// The `aspectRatio`.
    public var aspectRatio: Double {
        (rawResponse.originalWidth.double ?? 0)/(rawResponse.originalHeight.double ?? 1)
    }
}
