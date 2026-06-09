import Foundation

/// Safety ceilings applied to values parsed from untrusted ZPL.
///
/// The renderer parses attacker-controlled ZPL strings and turns them into
/// bitmap allocations. Without bounds, inputs like `^PW2305843009213693952`
/// trap on integer-overflow multiplications or request multi-gigabyte buffers.
/// Every dimension/size taken from ZPL is clamped against these constants so the
/// renderer degrades gracefully (skips, clamps, or throws) instead of crashing.
enum RenderLimits {
    /// Maximum label/graphic dimension in dots. Real labels are well under this
    /// (a 4x6 label at 300 DPI is 1200x1800 dots), so 20000 leaves generous
    /// headroom while bounding peak allocation to ~1.6 GB worst case
    /// (20000 * 20000 * 4 bytes) and keeping `width * 4` far from overflow.
    static let maxDimensionDots = 20_000

    /// Maximum bytes-per-row for a `^GF` graphic. `width = bytesPerRow * 8`, so
    /// this keeps the derived pixel width within `maxDimensionDots`.
    static let maxBytesPerRow = maxDimensionDots / 8  // 2500

    /// Maximum total decoded graphic size in bytes (1-bit bitmap). Bounds the
    /// `^GF` / `^GFC` decode buffers. `maxBytesPerRow * maxDimensionDots` rows of
    /// 1-bit data ~= 50 MB, a comfortable ceiling for any real label graphic.
    static let maxGraphicBytes = maxBytesPerRow * maxDimensionDots  // 50,000,000

    /// Maximum font height (dots) parsed from `^A` / `^CF`.
    static let maxFontHeight = maxDimensionDots

    /// Maximum text-block line count parsed from `^FB`.
    static let maxTextBlockLines = 10_000

    /// Maximum barcode bar height (dots) parsed from `^BC`/`^B3`/etc.
    static let maxBarcodeHeight = maxDimensionDots

    /// Maximum barcode module width / 2D magnification parsed from `^BY`/`^BQ`/etc.
    /// Scaling a CoreImage barcode by this is the dominant cost, so keep it small.
    static let maxBarcodeScale = 100

    /// Clamps `value` into `1...maxDimensionDots`. Used for label/graphic
    /// dimensions where 0 would produce an empty (useless) but also a degenerate
    /// context, and negatives are nonsensical.
    static func clampDimension(_ value: Int) -> Int {
        return min(max(value, 1), maxDimensionDots)
    }
}
