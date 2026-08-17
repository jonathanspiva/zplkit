#if canImport(Vision) && !os(watchOS)
import Foundation

/// Information about content near label edges, indicating potential clipping.
public struct BoundsInfo: Sendable, Hashable, Codable {
    /// Whether any detected content is near the top edge.
    public let hasTopEdgeContent: Bool

    /// Whether any detected content is near the bottom edge.
    public let hasBottomEdgeContent: Bool

    /// Whether any detected content is near the left edge.
    public let hasLeftEdgeContent: Bool

    /// Whether any detected content is near the right edge.
    public let hasRightEdgeContent: Bool

    /// Whether any content may be clipped at any edge.
    public var hasEdgeContent: Bool {
        hasTopEdgeContent || hasBottomEdgeContent || hasLeftEdgeContent || hasRightEdgeContent
    }

    /// A list of edges with potentially clipped content.
    public var affectedEdges: [Edge] {
        var edges: [Edge] = []
        if hasTopEdgeContent { edges.append(.top) }
        if hasBottomEdgeContent { edges.append(.bottom) }
        if hasLeftEdgeContent { edges.append(.left) }
        if hasRightEdgeContent { edges.append(.right) }
        return edges
    }

    /// Label edges.
    @frozen
    public enum Edge: String, Sendable, Codable, Hashable, CaseIterable {
        case top
        case bottom
        case left
        case right
    }

    public init(
        hasTopEdgeContent: Bool = false,
        hasBottomEdgeContent: Bool = false,
        hasLeftEdgeContent: Bool = false,
        hasRightEdgeContent: Bool = false
    ) {
        self.hasTopEdgeContent = hasTopEdgeContent
        self.hasBottomEdgeContent = hasBottomEdgeContent
        self.hasLeftEdgeContent = hasLeftEdgeContent
        self.hasRightEdgeContent = hasRightEdgeContent
    }

    /// Create bounds info from a collection of bounding boxes.
    static func from(boundingBoxes: [CGRect], threshold: CGFloat = 0.02) -> BoundsInfo {
        var top = false
        var bottom = false
        var left = false
        var right = false

        for box in boundingBoxes {
            if box.maxY > (1.0 - threshold) { top = true }
            if box.minY < threshold { bottom = true }
            if box.minX < threshold { left = true }
            if box.maxX > (1.0 - threshold) { right = true }
        }

        return BoundsInfo(
            hasTopEdgeContent: top,
            hasBottomEdgeContent: bottom,
            hasLeftEdgeContent: left,
            hasRightEdgeContent: right
        )
    }
}
#endif
