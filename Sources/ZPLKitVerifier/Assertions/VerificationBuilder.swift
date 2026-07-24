import Foundation

/// Result builder for creating verification expectations.
///
/// Supports control flow inside a verification block, so expectations can be
/// built conditionally or in a loop:
///
/// ```swift
/// try await verifier.verify(image) {
///     TextExpectation("FRAGILE")
///     if includeBarcode {
///         BarcodeExpectation(.qr, containing: "SKU-123")
///     }
///     for sku in skus {
///         BarcodeExpectation(.code128, exactly: sku)
///     }
/// }
/// ```
///
/// Each statement is lifted to a partial `[any Expectation]` by
/// ``buildExpression(_:)``, and ``buildBlock(_:)`` flattens the partials. The
/// `buildOptional` / `buildEither` / `buildArray` / `buildLimitedAvailability`
/// methods enable `if`, `if/else`, `for`, and `if #available` respectively.
@resultBuilder
public struct VerificationBuilder {
    /// Lifts a single expectation statement into a partial result.
    public static func buildExpression(_ expression: any Expectation) -> [any Expectation] {
        [expression]
    }

    /// Flattens the partial results of each statement in the block.
    public static func buildBlock(_ components: [any Expectation]...) -> [any Expectation] {
        components.flatMap { $0 }
    }

    /// Supports `for` loops (`buildArray`).
    public static func buildArray(_ components: [[any Expectation]]) -> [any Expectation] {
        components.flatMap { $0 }
    }

    /// Supports `if` without `else` (`buildOptional`).
    public static func buildOptional(_ component: [any Expectation]?) -> [any Expectation] {
        component ?? []
    }

    /// Supports the `if` branch of `if/else` (`buildEither`).
    public static func buildEither(first component: [any Expectation]) -> [any Expectation] {
        component
    }

    /// Supports the `else` branch of `if/else` (`buildEither`).
    public static func buildEither(second component: [any Expectation]) -> [any Expectation] {
        component
    }

    /// Supports `if #available` blocks (`buildLimitedAvailability`).
    public static func buildLimitedAvailability(_ component: [any Expectation]) -> [any Expectation] {
        component
    }
}
