//
//  cast.swift
//
//  Created by Guy on 28/10/2016.
//  Copyright © 2016 Houzz. All rights reserved.
//

import Foundation
import CoreGraphics

public protocol JSONValue {
    associatedtype Value = Self
    /** value from a json representation, typically deals with both the vaue represented as a string in the json
     *  and with the value itself stored in the json, e.g. both "2" and 2 will reqult in a correct Int value
     */
    static func value(from object: Any) -> Value?
    /** convert object to a value to store in a dictionary to convert to JSON
     * returning nil will not encode this property
     */
    var jsonValue: Any? { get }
}

public protocol JSONKey {
    var value: String { get }
    func contains(_ str: String) -> Bool
}

extension String: JSONKey {
    public var value: String {
        return self
    }
}

public protocol JSONDictionary {
    func any(forKeyPath path: JSONKey) -> Any?
    func any(for key: String) -> Any?
}

public extension JSONDictionary {
    public func any(forKeyPath path: JSONKey) -> Any? {
        let pathComponents = path.value.components(separatedBy: "/")
        var accumulator: Any = self

        for component in pathComponents {
            if let openIndex = component.range(of: "["), let closeIndex = component.range(of: "]") {
                let path = component.substring(to: openIndex.lowerBound)
                let indexString = component.substring(with: Range(uncheckedBounds: (openIndex.upperBound, closeIndex.lowerBound)))
                guard let index = Int(indexString) else {
                    return nil
                }
                if let componentData = accumulator as? Self, let value = componentData.any(for: path) as? [Any], value.count > index {
                    accumulator = value[index]
                    continue
                }
            } else if let componentData = accumulator as? Self, let value = componentData.any(for: component) {
                accumulator = value
                continue
            }
            return nil
        }

        return accumulator
    }

    public func value<A: JSONValue>(for key: JSONKey) -> A? {
        if let any = any(forKeyPath: key) {
            return A.value(from: any) as? A
        }
        return nil
    }

    public func value<A: JSONValue>(for key: JSONKey) -> [A]? {
        if let any = any(forKeyPath: key) {
            return Array<A>.value(from: any)
        }
        return nil
    }

    public func value<A: RawRepresentable>(for key: JSONKey) -> A? where A.RawValue: JSONValue {
        if let raw: A.RawValue = value(for: key) {
            return A(rawValue: raw)
        }
        return nil
    }

    public func value<A: RawRepresentable>(for key: JSONKey) -> [A]? where A.RawValue: JSONValue {
        if let rawArray: [A.RawValue] = value(for: key) {
            return rawArray.flatMap { A(rawValue: $0) }
        }
        return nil
    }
}

extension RawRepresentable {
    public var jsonValue: Any? {
        return self.rawValue
    }
}

extension RawRepresentable where RawValue: Castable {
    public static func decode(with decoder: NSCoder, fromKey key: String) -> Self? {
        guard let i = RawValue.decode(with: decoder, fromKey: key) else {
            return nil
        }
        return Self(rawValue: i)
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        self.rawValue.encode(with: coder, forKey: key)
    }
}

extension Dictionary: JSONDictionary, JSONValue {
    public func any(for key: String) -> Any? {
        guard let aKey = key as? Key else { return nil }
        return self[aKey]
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(self, forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> [Key: Value]? {
        return decoder.decodeObject(forKey: key) as? [Key: Value]
    }
}

extension Dictionary where Key: JSONKey {
    public func value(from object: Any) -> Value? {
        return object as? Value
    }
}

extension NSDictionary: JSONDictionary, JSONValue {
    public func any(for key: String) -> Any? {
        return self.object(forKey: key)
    }

    public func any(forKeyPath path: JSONKey) -> Any? {
        let pathComponents = path.value.components(separatedBy: "/")
        var accumulator: Any = self

        for component in pathComponents {
            if let openIndex = component.range(of: "["), let closeIndex = component.range(of: "]") {
                let path = component.substring(to: openIndex.lowerBound)
                let indexString = component.substring(with: Range(uncheckedBounds: (openIndex.upperBound, closeIndex.lowerBound)))
                guard let index = Int(indexString) else {
                    return nil
                }
                if let componentData = accumulator as? JSONDictionary, let value = componentData.any(for: path) as? [Any], value.count > index {
                    accumulator = value[index]
                    continue
                }
            } else if let componentData = accumulator as? JSONDictionary, let value = componentData.any(for: component) {
                accumulator = value
                continue
            }
            return nil
        }

        return accumulator
    }
}

extension JSONValue {
    public static func value(from object: Any) -> Value? {
        return object as? Value
    }

    public var jsonValue: Any? {
        return self
    }
}

public protocol Castable {
    func encode(with coder: NSCoder, forKey key: String)
    static func decode(with decoder: NSCoder, fromKey key: String) -> Self?
}

extension String: JSONValue, Castable {
    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(self, forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> String? {
        guard let i = decoder.decodeObject(forKey: key) as? String else {
            return nil
        }
        return i
    }
}

extension Int: JSONValue, Castable {
    public static func value(from object: Any) -> Int? {
        switch object {
        case let x as String:
            return Int(x)

        case let x as Int:
            return x

        default:
            return nil
        }
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(self, forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> Int? {
        if decoder.containsValue(forKey: key) {
            return Int(decoder.decodeInt64(forKey: key))
        }
        return nil
    }
}

extension Int8: JSONValue, Castable {
    public static func value(from object: Any) -> Int8? {
        switch object {
        case let x as String:
            return Int8(x)

        case let x as Int8:
            return x

        default:
            return nil
        }
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(Int32(self), forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> Int8? {
        if decoder.containsValue(forKey: key) {
            return Int8(decoder.decodeInt32(forKey: key))
        }
        return nil
    }
}

extension Int16: JSONValue, Castable {
    public static func value(from object: Any) -> Int16? {
        switch object {
        case let x as String:
            return Int16(x)

        case let x as Int16:
            return x

        default:
            return nil
        }
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(self, forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> Int16? {
        guard decoder.containsValue(forKey: key) else {
            return nil
        }
        return Int16(decoder.decodeInt32(forKey: key))
    }
}

extension Int32: JSONValue, Castable {
    public static func value(from object: Any) -> Int32? {
        switch object {
        case let x as String:
            return Int32(x)

        case let x as Int32:
            return x

        default:
            return nil
        }
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(self, forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> Int32? {
        guard decoder.containsValue(forKey: key) else {
            return nil
        }
        return decoder.decodeInt32(forKey: key)
    }
}

extension Int64: JSONValue, Castable {
    public static func value(from object: Any) -> Int64? {
        switch object {
        case let x as String:
            return Int64(x)

        case let x as Int64:
            return x

        default:
            return nil
        }
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(self, forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> Int64? {
        guard decoder.containsValue(forKey: key) else {
            return nil
        }

        return decoder.decodeInt64(forKey: key)
    }
}

extension Array where Element: JSONValue {
    public static func value(from object: Any) -> [Element]? {
        if let anyArray = object as? [Any] {
            return anyArray.flatMap { Element.value(from: $0) as? Element }
        }
        return nil
    }

    public var jsonValue: Any? {
        return self.map { $0.jsonValue }
    }
}

extension Array {
    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(self, forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> [Element]? {
        return decoder.decodeObject(forKey: key) as? [Element]
    }
}

extension Array where Element: RawRepresentable, Element.RawValue: JSONValue {
    public var jsonValue: Any? {
        return self.map { $0.jsonValue }
    }
}

extension UInt: JSONValue, Castable {
    public static func value(from object: Any) -> UInt? {
        switch object {
        case let x as String:
            return UInt(x)

        case let x as UInt:
            return x

        default:
            return nil
        }
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(Int32(self), forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> UInt? {
        guard decoder.containsValue(forKey: key) else {
            return nil
        }

        return UInt(decoder.decodeInt32(forKey: key))
    }
}

extension UInt8: JSONValue, Castable {
    public static func value(from object: Any) -> UInt8? {
        switch object {
        case let x as String:
            return UInt8(x)

        case let x as UInt8:
            return x

        default:
            return nil
        }
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(Int32(self), forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> UInt8? {
        guard decoder.containsValue(forKey: key) else {
            return nil
        }
        return UInt8(decoder.decodeInt32(forKey: key))
    }
}

extension UInt16: JSONValue, Castable {
    public static func value(from object: Any) -> UInt16? {
        switch object {
        case let x as String:
            return UInt16(x)

        case let x as UInt16:
            return x

        default:
            return nil
        }
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(Int32(self), forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> UInt16? {
        guard decoder.containsValue(forKey: key) else {
            return nil
        }
        return UInt16(decoder.decodeInt32(forKey: key))
    }
}

extension UInt32: JSONValue, Castable {
    public static func value(from object: Any) -> UInt32? {
        switch object {
        case let x as String:
            return UInt32(x)

        case let x as UInt32:
            return x

        default:
            return nil
        }
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(Int64(self), forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> UInt32? {
        guard decoder.containsValue(forKey: key) else {
            return nil
        }
        return UInt32(decoder.decodeInt64(forKey: key))
    }
}

extension UInt64: JSONValue, Castable {
    public static func value(from object: Any) -> UInt64? {
        switch object {
        case let x as String:
            return UInt64(x)

        case let x as UInt64:
            return x

        default:
            return nil
        }
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(Int64(self), forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> UInt64? {
        guard decoder.containsValue(forKey: key) else {
            return nil
        }
        return UInt64(decoder.decodeInt64(forKey: key))
    }
}

private let trueValues = Set(["true", "True", "TRUE", "yes", "Yes", "YES", "1", "on", "On", "ON"])

extension Bool: JSONValue, Castable {
    public static func value(from object: Any) -> Bool? {
        switch object {
        case let x as String:
            return trueValues.contains(x)

        case let x as Bool:
            return x

        default:
            return nil
        }
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(self, forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> Bool? {
        guard decoder.containsValue(forKey: key) else {
            return nil
        }
        return decoder.decodeBool(forKey: key)
    }
}

extension Float: JSONValue, Castable {
    public static func value(from object: Any) -> Float? {
        switch object {
        case let x as String:
            return Float(x)

        case let x as Float:
            return x

        default:
            return nil
        }
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(self, forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> Float? {
        guard decoder.containsValue(forKey: key) else {
            return nil
        }
        return decoder.decodeFloat(forKey: key)
    }
}

extension Double: JSONValue, Castable {
    public static func value(from object: Any) -> Double? {
        switch object {
        case let x as String:
            return Double(x)

        case let x as Double:
            return x

        default:
            return nil
        }
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(self, forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> Double? {
        guard decoder.containsValue(forKey: key) else {
            return nil
        }
        return decoder.decodeDouble(forKey: key)
    }
}

extension CGFloat: JSONValue, Castable {
    public static func value(from object: Any) -> CGFloat? {
        switch object {
        case let x as String:
            guard let d = Double(x) else {
                return nil
            }
            return CGFloat(d)

        case let x as Double:
            return CGFloat(x)

        case let x as Int:
            return CGFloat(x)

        case let x as CGFloat:
            return x

        default:
            return nil
        }
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(Double(self), forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> CGFloat? {
        guard decoder.containsValue(forKey: key) else {
            return nil
        }
        return CGFloat(decoder.decodeDouble(forKey: key))
    }
}

extension URL: JSONValue, Castable {
    public static func value(from object: Any) -> URL? {
        if let str = String.value(from: object) {
            return URL(string: str)
        }
        return nil
    }

    public var jsonValue: Any? {
        return self.absoluteString
    }

    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(self.absoluteString, forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> URL? {
        guard let i = decoder.decodeObject(forKey: key) as? String else {
            return nil
        }
        return URL(string: i)
    }
}

public extension NSCoding { // Make any class conforming to NSCoding work like Castable
    public func encode(with coder: NSCoder, forKey key: String) {
        coder.encode(self, forKey: key)
    }

    public static func decode(with decoder: NSCoder, fromKey key: String) -> Self? {
        return decoder.decodeObject(forKey: key) as? Self
    }
}

public protocol DictionaryConvertible: JSONValue {
    init?(dictionary: JSONDictionary)
    func dictionaryRepresentation() -> [String: Any]
}

extension DictionaryConvertible {
    public static func value(from object: Any) -> Self? {
        if let convertedObject = object as? JSONDictionary, let value = self.init(dictionary: convertedObject) {
            return value
        }
        return nil
    }

    public var jsonValue: Any? {
        return self.dictionaryRepresentation()
    }

    public init?(json: Data) {
        guard let dict = (try? JSONSerialization.jsonObject(with: json, options: JSONSerialization.ReadingOptions(rawValue: 0))) as? [String: Any] else {
            return nil
        }
        self.init(dictionary: dict)
    }

    public init?(json: String) {
        guard let dict = (try? JSONSerialization.jsonObject(with: json.data(using: String.Encoding.utf8)!, options: JSONSerialization.ReadingOptions(rawValue: 0))) as? [String: Any] else {
            return nil
        }
        self.init(dictionary: dict)
    }

    public func awake(with dictionary: JSONDictionary) -> Bool {
        return true
    }

    public func read(from dictionary: JSONDictionary) {
        fatalError("read(from:) not implemented, run JSON cast with -read option")
    }
}
