//
//  MediaResponse.swift
//  SwiftyInsta
//
//  Created by Stefano Bertagno on 02/08/2019.
//  Copyright © 2019 Mahdi. All rights reserved.
//

import CoreGraphics
import Foundation

/// A `Media` response.
public struct Media: IdentifiableParsedResponse {
    /// A media element `Version` response.
    public struct Version: ParsedResponse {
        /// Init with `rawResponse`.
        public init(rawResponse: DynamicResponse) { self.rawResponse = rawResponse }

        /// The `rawResponse`.
        public let rawResponse: DynamicResponse

        /// The `url`.
        public var url: URL? { rawResponse.dictionary?["url"]?.url }
        /// The `size` value.
        public var size: CGSize {
            CGSize(width: CGFloat(rawResponse.width.double ?? 0),
                   height: CGFloat(rawResponse.height.double ?? 1))
        }
        /// The `aspectRatio` value.
        public var aspectRatio: CGFloat {
            let size = self.size
            return size.width/size.height
        }
    }
    
    /// A `Picture` response.
    public struct Picture {
        /// The `versions` value.
        public let versions: [Version]
        
        /// Init with `rawResponse`.
        init(rawResponse: DynamicResponse) {
            self.versions = rawResponse.imageVersions2
                .candidates
                .array?
                .map(Version.init) ?? []
        }
    }
    /// A `Video` response.
    public struct Video {
        /// The `versions` value.
        public let versions: [Version]
        /// The `thumbnails` value.
        public let thumbnails: [Version]

        /// Init with `rawResponse`.
        init(rawResponse: DynamicResponse) {
            self.versions = rawResponse.videoVersions
                .array?
                .map(Version.init) ?? []
            self.thumbnails = rawResponse.imageVersions2
            .candidates
            .array?
            .map(Version.init) ?? []
        }
    }
    
    /// The content type.
    public enum Content {
        /// A picture.
        case picture(Picture)
        /// A video.
        case video(Video)
        /// An album.
        indirect case album([Content])
    }
    
    /// Init with `rawResponse`.
    public init(rawResponse: DynamicResponse) { self.rawResponse = rawResponse }

    /// The `rawResponse`.
    public let rawResponse: DynamicResponse

    /// The `expiringAt` value.
    public var expiringAt: Date {
        rawResponse.expiringAt
            .double
            .flatMap { $0 > 9_999_999_999 ? $0/1_000 : $0 }
            .flatMap { Date(timeIntervalSince1970: $0) } ?? .distantPast
    }
    /// The `takenAtDate` value.
    public var takenAt: Date {
        rawResponse.takenAt
            .double
            .flatMap { $0 > 9_999_999_999 ? $0/1_000 : $0 }
            .flatMap { Date(timeIntervalSince1970: $0) } ?? .distantPast
    }
    /// The `size` value.
    public var size: CGSize {
        CGSize(width: CGFloat(rawResponse.originalWidth.double ?? 0),
               height: CGFloat(rawResponse.originalHeight.double ?? 1))
    }
    /// The `aspectRatio` value.
    public var aspectRatio: CGFloat {
        let size = self.size
        return size.width/size.height
    }
    /// The `content` value.
    public var content: Content? {
        switch rawResponse.mediaType.int {
        case 1?: return .picture(.init(rawResponse: rawResponse))
        case 2?: return .video(.init(rawResponse: rawResponse))
        case 8?: return .album([])
        default: return nil
        }
    }
}
