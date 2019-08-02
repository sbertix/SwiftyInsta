//
//  ParsedResponse.swift
//  SwiftyInsta
//
//  Created by Stefano Bertagno on 30/07/2019.
//  Copyright © 2019 Mahdi. All rights reserved.
//

import Foundation

/// A `protocol` holding reference to endpoint responses.
public protocol ParsedResponse {
    /// The associated `JSON` response.
    var rawResponse: DynamicResponse { get }

    /// Init with `rawResponse`.
    init(rawResponse: DynamicResponse)
}
/// A pseudo-`Coding` extension.
public extension ParsedResponse {
    /// Encode.
    func encode() throws -> Data {
        return try rawResponse.data()
    }
    /// Decode.
    static func decode(data: Data) throws -> Self {
        return try Self(rawResponse: DynamicResponse(data: data))
    }
}

/// The identifier type.
/// Most of `Instagram` models for their responses, contain both a numerical `pk`, representing the _primaryKey_ (i.e. unique)
/// of the element in the _database_, and a string `id`, which is usually used to acces their info from the outside
/// (and it's supposed to still be unique).
/// `Identifier<Element>` allows to store everything related to "identifying" a response in one place, while also,
/// thanks to the `Element` reference, allow for type specific comparisons.
public struct Identifier<Element>: Hashable {
    /// The **numerical** primary key.
    public var primaryKey: Int?
    /// The **string** identifier.
    public var identifier: String?

    /// Init with `primaryKey` and `identifier`.
    public init(primaryKey: Int? = nil, identifier: String? = nil) {
        self.primaryKey = primaryKey
        self.identifier = identifier
    }
    /// Return a copy with an updated `primaryKey`.
    public func primaryKey(_ primaryKey: Int) -> Identifier<Element> {
        return .init(primaryKey: primaryKey, identifier: self.identifier)
    }
    /// Return a copy with an updated `identifier`.
    public func identifier(_ identifier: String) -> Identifier<Element> {
        return .init(primaryKey: self.primaryKey, identifier: identifier)
    }
}
/// An **identifiable** `ParsedResponse`.
public protocol IdentifiableParsedResponse: ParsedResponse {
    /// The identifier.
    var identity: Identity { get }
}
public extension IdentifiableParsedResponse {
    /// The identifier type.
    typealias Identity = Identifier<Self>
    /// The identifier.
    var identity: Identifier<Self> {
        .init(primaryKey: rawResponse.pk.int ?? rawResponse.pk.string.flatMap(Int.init),
              identifier: rawResponse.id.string ?? "")
    }
}
