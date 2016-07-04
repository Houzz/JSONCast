//
//  Mapper.swift
//
//  Created by Guy on 12/05/2016.
//  Copyright © 2016 Houzz. All rights reserved.
//

import Foundation
import CoreGraphics

public protocol DictionaryConvertible {
    init?(dictionary: [String: AnyObject])
    func dictionaryRepresentation() -> [String: AnyObject]
}

public extension DictionaryConvertible {
    init?(json: NSData) {
        guard let dict = (try? NSJSONSerialization.JSONObjectWithData(json, options: NSJSONReadingOptions(rawValue: 0))) as? [String: AnyObject] else {
            return nil
        }
        self.init(dictionary: dict)
    }

    init?(json: String) {
        guard let dict = (try? NSJSONSerialization.JSONObjectWithData(json.dataUsingEncoding(NSUTF8StringEncoding)!, options: NSJSONReadingOptions(rawValue: 0))) as? [String: AnyObject] else {
            return nil
        }
        self.init(dictionary: dict)
    }
}

public protocol BasicType {
    static func fromDictionaryValue(object: AnyObject) -> Self
}

extension Int: BasicType {
    public static func fromDictionaryValue(object: AnyObject) -> Int {
        switch object {
        case let x as Int:
            return x

        case let x as String:
            return Int(x)!

        default:
            return 0
        }
    }
}

extension UInt: BasicType {
    public static func fromDictionaryValue(object: AnyObject) -> UInt {
        switch object {
        case let x as UInt:
            return x

        case let x as String:
            return UInt(x)!

        default:
            return 0
        }
    }
}

extension CGFloat: BasicType {
    public static func fromDictionaryValue(object: AnyObject) -> CGFloat {
        switch object {
        case let x as CGFloat:
            return x

        case let x as String:
            return CGFloat(Double(x)!)

        default:
            return 0
        }
    }
}

extension Double: BasicType {
    public static func fromDictionaryValue(object: AnyObject) -> Double {
        switch object {
        case let x as Double:
            return x

        case let x as String:
            return Double(x)!

        default:
            return 0
        }
    }
}

extension Float: BasicType {
    public static func fromDictionaryValue(object: AnyObject) -> Float {
        switch object {
        case let x as Float:
            return x

        case let x as String:
            return Float(x)!

        default:
            return 0
        }
    }
}

extension Bool: BasicType {
    public static func fromDictionaryValue(object: AnyObject) -> Bool {
        switch object {
        case let x as Bool:
            return x

        case let x as NSString:
            return x.boolValue

        default:
            return false
        }
    }
}

extension String: BasicType {
    public static func fromDictionaryValue(object: AnyObject) -> String {
        switch object {
        case let x as String:
            return x

        default:
            return ""
        }
    }
}

public class Mapper {
    public class func map<V: DictionaryConvertible>(object: AnyObject?) -> [V]? {
        switch object {
        case let dictArray as [[String: AnyObject]]:
            var items = [V]()
            for item in dictArray {
                if let x = V.init(dictionary: item) {
                    items.append(x)
                }
            }
            return items

        default:
            return nil
        }
    }

    public class func map<V: DictionaryConvertible>(object: AnyObject?) -> V? {
        switch object {
        case let item as [String: AnyObject]:
            return V.init(dictionary: item)

        default:
            return nil
        }
    }

    public class func map(object: AnyObject?) -> [String: AnyObject]? {
        switch object {
        case let d as [String: AnyObject]:
            return d

        default:
            return nil
        }
    }

    public class func map(object: AnyObject?) -> [String: String]? {
        switch object {
        case let d as [String: String]:
            return d

        default:
            return nil
        }
    }

    public class func map<V: BasicType>(object: AnyObject?) -> [V]? {
        switch object {
        case let array as [AnyObject]:
            var items = [V]()
            for item in array {
                items.append(V.fromDictionaryValue(item))
            }
            return items

        default:
            return nil
        }
    }

    public class func map(object: AnyObject?) -> CGFloat? {
        switch object {
        case let x as CGFloat:
            return x

        case let str as String:
            return CGFloat(Double(str)!)

        default:
            return nil
        }
    }

    public class func map(object: AnyObject?) -> Double? {
        switch object {
        case let x as Double:
            return x

        case let str as String:
            return Double(str)

        default:
            return nil
        }
    }

    public class func map(object: AnyObject?) -> Int? {
        switch object {
        case let x as Int:
            return x

        case let str as String:
            return Int(str)

        default:
            return nil
        }
    }

    public class func map(object: AnyObject?) -> UInt? {
        switch object {
        case let x as UInt:
            return x

        case let str as String:
            return UInt(str)

        default:
            return nil
        }
    }

    public class func map(object: AnyObject?) -> String? {
        switch object {
        case let str as String:
            return str

        default:
            return nil
        }
    }

    public class func map(object: AnyObject?) -> Bool? {
        switch object {
        case let x as Bool:
            return x

        case let str as NSString:
            return str.boolValue

        default:
            return nil
        }
    }

    public class func map(object: AnyObject?) -> NSURL? {
        switch object {
        case let x as NSURL:
            return x

        case let x as String:
            return NSURL(string: x)

        default:
            return nil
        }
    }

    public class func map(object: AnyObject?) -> [NSURL]? {
        if let object = object as? [AnyObject] {
            var items = [NSURL]()
            for item in object {
                if let u: NSURL = Mapper.map(item) {
                    items.append(u)
                }
            }
            return items
        }
        return nil
    }

    public class func unmap(object: Any?) -> AnyObject? {
        return object as? AnyObject
    }

    public class func lowercaseDictionary(dict: [String: AnyObject]?) -> [String: AnyObject]? {
        guard let dict = dict else {
            return nil
        }
        var outDict = [String: AnyObject]()
        for (key, object) in dict {
            outDict[key.lowercaseString] = object
        }
        return outDict
    }
}
