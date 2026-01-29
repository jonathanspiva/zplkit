/// Result builder for constructing label content.
@resultBuilder
public struct ZPLBuilder {
    public static func buildBlock(_ components: ZPLElement...) -> [ZPLElement] {
        components
    }

    public static func buildBlock(_ components: [ZPLElement]...) -> [ZPLElement] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [ZPLElement]?) -> [ZPLElement] {
        component ?? []
    }

    public static func buildEither(first component: [ZPLElement]) -> [ZPLElement] {
        component
    }

    public static func buildEither(second component: [ZPLElement]) -> [ZPLElement] {
        component
    }

    public static func buildArray(_ components: [[ZPLElement]]) -> [ZPLElement] {
        components.flatMap { $0 }
    }

    /// Handles failable barcode initializers by accepting optionals.
    public static func buildExpression(_ expression: ZPLElement?) -> [ZPLElement] {
        if let element = expression {
            return [element]
        }
        return []
    }

    public static func buildExpression(_ expression: ZPLElement) -> [ZPLElement] {
        [expression]
    }
}
