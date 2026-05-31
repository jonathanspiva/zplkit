import Foundation

/// Result builder for creating verification expectations.
@resultBuilder
public struct VerificationBuilder {
    public static func buildBlock(_ components: (any Expectation)...) -> [any Expectation] {
        components
    }

    public static func buildArray(_ components: [[any Expectation]]) -> [any Expectation] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [any Expectation]?) -> [any Expectation] {
        component ?? []
    }

    public static func buildEither(first component: [any Expectation]) -> [any Expectation] {
        component
    }

    public static func buildEither(second component: [any Expectation]) -> [any Expectation] {
        component
    }

    public static func buildExpression(_ expression: any Expectation) -> any Expectation {
        expression
    }

    public static func buildLimitedAvailability(_ component: [any Expectation]) -> [any Expectation] {
        component
    }
}
