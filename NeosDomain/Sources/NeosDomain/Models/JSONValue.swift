import Foundation

/// Type-safe representation of JSON values, replacing `Any` in HEOS responses.
public enum JSONValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([Self])
    case object([String: Self])

    // MARK: - Accessors

    public var asString: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    public var asInt: Int? {
        switch self {
        case .int(let v): return v
        case .double(let v): return Int(exactly: v)
        default: return nil
        }
    }

    public var asDouble: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v): return Double(v)
        default: return nil
        }
    }

    public var asBool: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    public var asArray: [Self]? {
        if case .array(let v) = self { return v }
        return nil
    }

    public var asObject: [String: Self]? {
        if case .object(let v) = self { return v }
        return nil
    }

    /// Convenience: get an array of dictionaries (common HEOS payload shape).
    public var asObjectArray: [[String: Self]] {
        asArray?.compactMap(\.asObject) ?? []
    }

    // MARK: - Subscript

    public subscript(key: String) -> Self? {
        asObject?[key]
    }

    public subscript(index: Int) -> Self? {
        guard let arr = asArray, arr.indices.contains(index) else { return nil }
        return arr[index]
    }

    // MARK: - Factory

    /// Convert from a `JSONSerialization` result (`Any`) into a typed `JSONValue`.
    public static func from(_ value: Any) -> Self {
        switch value {
        case let s as String:
            return .string(s)
        case let n as NSNumber:
            // NSNumber wraps bools, ints, and doubles; check bool first
            if CFBooleanGetTypeID() == CFGetTypeID(n) {
                return .bool(n.boolValue)
            }
            if n.doubleValue == Double(n.intValue) && !"\(n)".contains(".") {
                return .int(n.intValue)
            }
            return .double(n.doubleValue)
        case let arr as [Any]:
            return .array(arr.map(Self.from))
        case let dict as [String: Any]:
            return .object(dict.mapValues(Self.from))
        case is NSNull:
            return .null
        default:
            return .null
        }
    }
}
