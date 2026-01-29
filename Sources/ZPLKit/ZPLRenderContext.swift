/// Context passed to elements during rendering.
/// Contains label configuration needed for unit conversion.
public struct ZPLRenderContext: Sendable {
    /// The DPI of the target printer.
    public let dpi: DPI

    /// Label width in dots.
    public let labelWidth: Int

    /// Label height in dots.
    public let labelHeight: Int

    /// Creates a render context.
    public init(dpi: DPI, labelWidth: Int, labelHeight: Int) {
        self.dpi = dpi
        self.labelWidth = labelWidth
        self.labelHeight = labelHeight
    }
}
