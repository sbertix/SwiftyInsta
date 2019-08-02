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
    /// Init with `rawResponse`.
    public init(rawResponse: DynamicResponse) { self.rawResponse = rawResponse }

    /// The `rawResponse`.
    public let rawResponse: DynamicResponse

    /// The actual `TrayElement`s.
    public var items: [TrayElement] {
        return rawResponse.tray.array?.compactMap { TrayElement(rawResponse: $0) } ?? []
    }
}

/// A `TrayElement` response.
public struct TrayElement: IdentifiableParsedResponse {
    /// Init with `rawResponse`.
    public init(rawResponse: DynamicResponse) { self.rawResponse = rawResponse }

    /// The `rawResponse`.
    public let rawResponse: DynamicResponse

    /// The `latestReelMedia` value.
    public var updatedAt: Date {
        rawResponse.latestReelMedia
            .double
            .flatMap { $0 > 9_999_999_999 ? $0/1_000 : $0 }
            .flatMap { Date(timeIntervalSince1970: $0) } ?? .distantPast
    }
    /// The `expiringAtDate` value.
    public var expiringAt: Date {
        rawResponse.expiringAt
            .double
            .flatMap { $0 > 9_999_999_999 ? $0/1_000 : $0 }
            .flatMap { Date(timeIntervalSince1970: $0) } ?? .distantPast
    }
    /// The `lastSeenOnDate` value.
    public var lastSeenOn: Date {
        rawResponse.seen
            .double
            .flatMap { $0 > 9_999_999_999 ? $0/1_000 : $0 }
            .flatMap { Date(timeIntervalSince1970: $0) } ?? .distantPast
    }
    /// The `hasBestiesMedia` value.
    public var containsBestiesOnlyMedia: Bool {
        rawResponse.hasBestiesMedia.bool ?? false
    }
    /// The `muted` value.
    public var isMuted: Bool {
        rawResponse.muted.bool ?? false
    }
    /// The `media` value.
    public var media: [Media] {
        rawResponse.items.array?.compactMap { Media(rawResponse: $0) } ?? []
    }
    /// The `user` value.
    public var user: User! {
        User(rawResponse: rawResponse.user)
    }
}

