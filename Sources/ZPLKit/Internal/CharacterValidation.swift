extension Character {
    /// True only for ASCII "0"-"9".
    ///
    /// `isNumber` also accepts non-ASCII numerics (fullwidth digits,
    /// Arabic-Indic digits, vulgar fractions), which would pass barcode
    /// validation and then be emitted into `^FD` as raw multibyte UTF-8.
    var isASCIIDigit: Bool {
        isASCII && isWholeNumber
    }
}
