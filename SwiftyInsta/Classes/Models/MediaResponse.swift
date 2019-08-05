//
//  MediaResponse.swift
//  SwiftyInsta
//
//  Created by Stefano Bertagno on 08/02/2019.
//  Copyright © 2019 Mahdi. All rights reserved.
//

import CoreGraphics
import Foundation

/// A `Media` response.
public struct Media: IdentifiableParsedResponse {
    /// A media element `Version` response.
    public struct Version {
        /// The `url`.
        public var url: URL
        /// The `size` value.
        public var size: CGSize

        /// The `aspectRatio` value.
        public var aspectRatio: CGFloat { size.width/size.height }
        /// The `resolution` value.
        public var resolution: CGFloat { size.width*size.height }

        /// Init with `rawResponse`.
        init?(rawResponse: DynamicResponse) {
            guard let url = rawResponse.dictionary?["url"]?.url else { return nil }
            self.url = url
            self.size = CGSize(width: CGFloat(rawResponse.width.double ?? 0),
                               height: CGFloat(rawResponse.height.double ?? 1))
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
                .compactMap(Version.init) ?? []
        }
    }
    /// A `Video` response.
    public struct Video {
        /// The `videoDuration` value.
        public let duration: TimeInterval
        /// The `versions` value.
        public let versions: [Version]
        /// The `thumbnails` value.
        public let thumbnails: [Version]

        /// Init with `rawResponse`.
        init(rawResponse: DynamicResponse) {
            self.duration = rawResponse.videoDuration.double ?? .nan
            self.versions = rawResponse.videoVersions
                .array?
                .compactMap(Version.init) ?? []
            self.thumbnails = rawResponse.imageVersions2
                .candidates
                .array?
                .compactMap(Version.init) ?? []
        }
    }

    /// The content type.
    public enum Content {
        /// A picture.
        case picture(Picture)
        /// A video.
        case video(Video)
        /// An album.
        case album([Content])
        /// No content.
        case none
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
    /// The `resolution` value.
    public var resolution: CGFloat {
        let size = self.size
        return size.width*size.height
    }

    /// The `caption` value.
    public var caption: Comment { Comment(rawResponse: rawResponse.caption) }
    /// The `commentCount` value.
    public var comments: Int { rawResponse.commentCount.int ?? 0 }
    /// The `likeCount` value.
    public var likes: Int { rawResponse.likeCount.int ?? 0 }
    /// The `content` value.
    public var content: Content {
        switch rawResponse.mediaType.int {
        case 1?: return .picture(.init(rawResponse: rawResponse))
        case 2?: return .video(.init(rawResponse: rawResponse))
        case 8?: return .album([])
        default: return .none
        }
    }
    /// The `user` value.
    public var user: User? {
        User(rawResponse: rawResponse.user == .none ? rawResponse.owner : rawResponse.user)
    }
}

/// `Content` accessories.
public extension Media.Content {
    /// Return `versions` of `.picture` and `thumbnails` of `.video`.
    var thumbnails: [[Media.Version]] {
        switch self {
        case .picture(let picture): return [picture.versions]
        case .video(let video): return [video.thumbnails]
        case .album(let album): return album.compactMap { $0.thumbnails.first }
        default: return []
        }
    }
}

/// `[[Version]]` accessories.
public extension Collection where Element: Collection, Element.Element == Media.Version {
    /// Return `Element`s with aspect ratio equal to `aspectRatio`.
    func with(aspectRatio: CGFloat) -> [[Media.Version]] { return map { $0.with(aspectRatio: aspectRatio) }}
    /// Return `Element`s with `aspectRatio` equal to `1`.
    var squared: [[Media.Version]] { map { $0.squared }}

    /// Return the highest quality `Element`.
    var largest: [Media.Version?] { map { $0.largest }}
    /// Return the lowest quality `Element`.
    var smallest: [Media.Version?] { map { $0.smallest }}
}
/// `[Version?]` accessories.
public extension Collection where Element == Media.Version? {
    /// Compact map the collection.
    var valid: [Media.Version] { compactMap { $0 }}
}
/// `[Version]` accessories.
public extension Collection where Element == Media.Version {
    /// Return `Element`s with aspect ratio equal to `aspectRatio`.
    func with(aspectRatio: CGFloat) -> [Media.Version] { return filter { $0.aspectRatio == aspectRatio }}
    /// Return `Element`s with `aspectRatio` equal to `1`.
    var squared: [Media.Version] { with(aspectRatio: 1) }

    /// Return the highest quality `Element`.
    var largest: Media.Version? { self.max(by: { lhs, rhs in lhs.resolution < rhs.resolution }) }
    /// Return the smallest quality `Element`.
    var smallest: Media.Version? { self.min(by: { lhs, rhs in lhs.resolution < rhs.resolution }) }
}
