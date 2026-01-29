/// Protocol that all label elements conform to.
public protocol ZPLElement: Sendable {
    /// Renders this element to a ZPL string.
    func render(context: ZPLRenderContext) -> String
}
