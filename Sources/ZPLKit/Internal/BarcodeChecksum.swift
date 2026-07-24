/// GTIN-family modulo-10 check digit (EAN-13, EAN-8, UPC-A).
///
/// All three use the same rule: weight the data digits 3,1,3,1,... from the
/// rightmost data digit, sum, then the check digit is `(10 - sum % 10) % 10`.
/// `digits` must be the data digits only (without the trailing check digit).
func gtinCheckDigit(_ digits: [Int]) -> Int {
    var sum = 0
    for (offset, digit) in digits.reversed().enumerated() {
        sum += digit * (offset.isMultiple(of: 2) ? 3 : 1)
    }
    return (10 - (sum % 10)) % 10
}

/// Validates a fully-specified numeric barcode string whose last digit is the
/// GTIN check digit. Returns `true` if the trailing digit matches the check
/// digit computed from the leading digits. Assumes `data` is all ASCII digits.
func hasValidGTINCheckDigit(_ data: String) -> Bool {
    let digits = data.compactMap { $0.wholeNumberValue }
    guard digits.count == data.count, digits.count >= 2 else { return false }
    let expected = gtinCheckDigit(Array(digits.dropLast()))
    return digits.last == expected
}
