//
//  ThreadResponse.swift
//  SwiftyInsta
//
//  Created by Stefano Bertagno on 05/08/2019.
//  Copyright © 2019 Mahdi. All rights reserved.
//

import Foundation

/// A `Thread` response.
public struct Thread: ThreadIdentifiableParsedResponse {
    /// Init with `rawResponse`.
    public init(rawResponse: DynamicResponse) { self.rawResponse = rawResponse }

    /// The `rawResponse`.
    public let rawResponse: DynamicResponse

    /// The `muted` value.
    public var isMuted: Bool { rawResponse.muted.bool ?? false }
    /// The `threadTitle` value.
    public var title: String { rawResponse.threadTitle.string ?? "" }
    /// The `isGroup` value.
    public var isGroup: Bool { rawResponse.isGroup.bool ?? false }

    /// The `users` value.
    public var users: [User] { rawResponse.users.array?.map(User.init) ?? [] }
    /// The `messages` value.
    public var messages: [Message] { rawResponse.items.array?.map(Message.init) ?? [] }
}

/// A `Message` response.
public struct Message: ItemIdentifiableParsedResponse, UserIdentifiableParsedResponse {
    /// Init with `rawResponse`.
    public init(rawResponse: DynamicResponse) { self.rawResponse = rawResponse }

    /// The `rawResponse`.
    public let rawResponse: DynamicResponse

    /// The `timestamp` value.
    public var sentAt: Date {
        rawResponse.timestamp
            .double
            .flatMap { $0 > 9_999_999_999 ? $0/1_000 : $0 }
            .flatMap { Date(timeIntervalSince1970: $0) } ?? .distantPast
    }
    /// The `text` value.
    public var text: String? {
        rawResponse.text.string
    }
}

/// A `Recipient` model.
public struct Recipient: ParsedResponse {
    /// Init with `rawResponse`.
    public init(rawResponse: DynamicResponse) { self.rawResponse = rawResponse }

    /// The `rawResponse`.
    public let rawResponse: DynamicResponse

    /// The `user` value.
    public var user: User? { User(rawResponse: rawResponse.user) }
    /// The `thread` value.
    public var thread: Thread? { Thread(rawResponse: rawResponse.thread) }
}
