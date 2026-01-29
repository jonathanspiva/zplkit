/// Built-in ZPL fonts.
///
/// Most applications should use ``default`` (Font 0), which is a scalable
/// font available on all Zebra printers.
///
/// ## Usage
///
/// ```swift
/// Text("Hello", at: .inches(0.5, 0.5))
///     .font(.default, height: .inches(0.15))
/// ```
///
/// ## Font 0 (Default)
///
/// Font 0 is the recommended choice because:
/// - It's scalable to any size
/// - It's available on all Zebra printers
/// - ZPLKitRenderer includes Roboto Condensed Bold for accurate previews
///
/// ## Other Fonts
///
/// Fonts A-V are bitmap fonts with fixed sizes. They may render differently
/// across printer models and are generally not recommended unless you have
/// specific requirements.
public enum ZPLFont: String, Sendable {
    /// Scalable font (Font 0). Recommended for most use cases.
    case `default` = "0"
    /// Bitmap font A.
    case a = "A"
    /// Bitmap font B.
    case b = "B"
    /// Bitmap font C.
    case c = "C"
    /// Bitmap font D.
    case d = "D"
    /// Bitmap font E.
    case e = "E"
    /// Bitmap font F.
    case f = "F"
    /// Bitmap font G.
    case g = "G"
    /// Bitmap font H.
    case h = "H"
    /// Bitmap font P.
    case p = "P"
    /// Bitmap font Q.
    case q = "Q"
    /// Bitmap font R.
    case r = "R"
    /// Bitmap font S.
    case s = "S"
    /// Bitmap font T.
    case t = "T"
    /// Bitmap font U.
    case u = "U"
    /// Bitmap font V.
    case v = "V"
}
