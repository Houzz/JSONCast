#!/usr/bin/env -i xcrun -sdk macosx swift
//  Copyright © 2016 Houzz. All rights reserved.

import Foundation

var classInheritence: [String]?
var className: String?
var output = [String]()
var callAwake = false
var nscoding = false
var upperCase = false
var enumMapping = [String: String]()
var isStruct = false
var classAccess = ""
var didImportCast = false
var nullEmptyString = false
var ignoreCase = false

let encodeMap = [
    "Bool": ("aCoder.encodeBool(%@, forKey: \"%@\")", "aDecoder.decodeBoolForKey(\"%@\")"),
    "Float": ("aCoder.encodeFloat(%@, forKey: \"%@\")", "aDecoder.decodeFloatForKey(\"%@\")"),
    "Double": ("aCoder.encodeDouble(%@, forKey: \"%@\")", "aDecoder.decodeDoubleForKey(\"%@\")"),
    "CGFloat": ("aCoder.encodeDouble(Double(%@), forKey: \"%@\")", "CGFloat(aDecoder.decodeDoubleForKey(\"%@\"))"),
    "Int": ("aCoder.encodeInteger(%@, forKey: \"%@\")", "aDecoder.decodeIntegerForKey(\"%@\")"),
    "UInt": ("aCoder.encodeInteger(Int(%@), forKey: \"%@\")", "UInt(aDecoder.decodeIntegerForKey(\"%@\"))")
]

class Regex {
    private let expression: NSRegularExpression
    private var match: NSTextCheckingResult?

    init(_ pattern: String, options: NSRegularExpressionOptions = []) {
        self.expression = try! NSRegularExpression(pattern: pattern, options: options)
    }

    func matchGroups(input: String) -> [String?]? {
        match = expression.firstMatchInString(input, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, input.characters.count))
        if let match = match {
            var captures = [String?]()
            for group in 0 ..< match.numberOfRanges {
                let r = match.rangeAtIndex(group)
                if r.location != NSNotFound {
                    let stringMatch = (input as NSString).substringWithRange(match.rangeAtIndex(group))
                    captures.append(stringMatch)
                } else {
                    captures.append(nil)
                }
            }
            return captures
        } else {
            return nil
        }
    }

    func match(input: String) -> Bool {
        match = expression.firstMatchInString(input, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, input.characters.count))
        return match != nil
    }

    func replace(input: String, with template: String) -> String {
        return expression.stringByReplacingMatchesInString(input, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, input.characters.count), withTemplate: template)
    }

    func numberOfMatchesIn(input: String) -> Int {
        return expression.matchesInString(input, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, input.characters.count)).count
    }
}

extension String {
    func replace(regex: Regex, with template: String) -> String {
        return regex.replace(self, with: template)
    }
}

infix operator ~ { associativity left precedence 150 }
func ~(left: Regex, right: String) -> Bool {
    return left.match(right)
}
func ~(left: Regex, right: String) -> [String?]? {
    return left.matchGroups(right)
}

struct VarInfo {
    let name: String
    let type: String
    let defaultValue: String?
    let key: String
    var optional: Bool
    let isNullable: Bool

    init(name: String, type: String, defaultValue: String? = nil, key: String? = nil) {
        self.name = name
        if type.hasSuffix("?") || type.hasSuffix("!") {
            self.isNullable = true
            self.type = type.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "!?"))
            self.optional = type.hasSuffix("?")
        } else {
            self.type = type
            self.optional = false
            self.isNullable = false
        }
        if upperCase {
            let n = name as NSString
            self.key = key ?? n.substringToIndex(1).capitalizedString + n.substringFromIndex(1)
        } else if ignoreCase {
            self.key = (key ?? name).lowercaseString
        } else {
            self.key = key ?? name
        }
        self.defaultValue = defaultValue
    }

    var isEnum: Bool {
        get {
            return enumMapping[type] != nil
        }
    }

    var rawType: String? {
        get {
            return enumMapping[type]
        }
    }

    var encodeCall: String {
        get {
            var ret = ""
            var vv = name
            var vtype = type
            if optional {
                vv = "v"
                ret += "if let v = \(name) {\n"
            }

            if let rawType = enumMapping[vtype] {
                vv = "\(vv).rawValue"
                vtype = rawType
            }
            if let f = encodeMap[vtype] {
                ret += String(format: f.0, vv, name)
            } else {
                ret += "aCoder.encodeObject(\(vv), forKey: \"\(name)\")"
            }

            if optional {
                ret += "\n\t\t}"
            }

            return ret
        }
    }

    var decodeCall: String {
        get {
            var vtype = type
            if let rawType = enumMapping[vtype] {
                vtype = rawType
            }

            var v: String
            if let f = encodeMap[vtype] {
                let enc = String(format: f.1, name)
                v = "\t\tif aDecoder.containsValueForKey(\"\(name)\") { let v = \(enc)"
            } else {
                v = "if let v = aDecoder.decodeObjectForKey(\"\(name)\") as? \(vtype) {"
            }

            if vtype != type {
                v += "\n\t\t\t\(name) = \(type)(rawValue: v)!"
            } else {
                v += "\n\t\t\t\(name) = v"
            }

            v += "\n\t\t}"

            if let def = defaultValue {
                v += " else { \(name) = \(def) }"
            } else if optional {
                v += " else { \(name) = nil }"
            } else {
                v += " else { return nil }"
            }

            return v
        }
    }

    func initFromKey(aKey: String) {
        var mapStatement = "Mapper.map(dict[\"\(aKey)\"])"
        if isEnum {
            output.append("if let v: \(rawType!) = \(mapStatement) {")
            mapStatement = "\(type)(rawValue: v)"
        }

        var whereStatement = ""
        if nullEmptyString && type == "String" {
            whereStatement = "where !v.isEmpty "
        }

        output.append("if let v: \(type) = \(mapStatement) \(whereStatement){ ")
        output.append("\(name) = v")

        if let def = defaultValue {
            output.append("} else { \(name) = \(def) }")
        } else if !optional {
            output.append("} else { return nil }")
        } else if isNullable {
            output.append("} else { \(name) = nil }")
        } else {
            output.append("}")
        }

        if isEnum {
            if let def = defaultValue {
                output.append("} else { \(name) = \(def) }")
            } else if !optional {
                output.append("} else { return nil }")
            } else if isNullable {
                output.append("} else { \(name) = nil }")
            } else {
                output.append("}")
            }
        }
    }
}
var variables = [VarInfo]()

func createFunctions() {
    var override = ""
    if classInheritence == nil {
        classInheritence = [String]()
    }
    if !classInheritence!.contains("DictionaryConvertible") {
        override = "override"
    }

    // init
    let reqStr = isStruct ? "" : "required"

    if ignoreCase {
        output.append("\(reqStr) \(classAccess) init?(dictionary unknownCaseDict: [String: AnyObject]) {")
        output.append("        guard let dict = Mapper.lowercaseDictionary(unknownCaseDict) else { return nil }")
    } else {
        output.append("\(reqStr) \(classAccess) init?(dictionary dict: [String: AnyObject]) {")
    }

    for variable in variables {
        let comp = variable.key.componentsSeparatedByString("/")
        for (idx, aKey) in comp.enumerate() {
            if idx == comp.count - 1 {
                variable.initFromKey(aKey)
                for _ in 0 ..< idx {
                    if let def = variable.defaultValue {
                        output.append("\t\t} else { \(variable.name) = \(def) }")
                    } else if !variable.optional {
                        output.append("\t\t} else { return nil }")
                    } else {
                        output.append("\t\t} else { \(variable.name) = nil }")
                    }
                }
            } else {
                if ignoreCase {
                    output.append("\t\tif let dict = Mapper.lowercaseDictionary(dict[\"\(aKey)\"] as? [String: AnyObject]) {")
                } else {
                    output.append("\t\tif let dict = dict[\"\(aKey)\"] as? [String: AnyObject] {")
                }
            }
        }
    }

    if !override.isEmpty {
        output.append("\t\tsuper.init(dictionary: dict)")
    }

    if callAwake {
        if classInheritence!.indexOf("DictionaryConvertible") > 0 {
            output.append("\t\tsuper.init()")
        }
        output.append("\t\tif !awakeWithDictionary(dict) { return nil }")
    }

    output.append("\t}")

    // dictionaryRepresentation()
    output.append("\t\(override) \(classAccess) func dictionaryRepresentation() -> [String: AnyObject] {")
    if override.isEmpty {
        output.append("\t\tvar dict = [String: AnyObject]()")
    } else {
        output.append("\t\tvar dict = super.dictionaryRepresentation()")
    }

    for variable in variables {
        let keys = variable.key.componentsSeparatedByString("/")
        for (idx, key) in keys.enumerate() {
            let dName = (idx == 0) ? "dict" : "dict\(idx)"
            if idx == keys.count - 1 {
                output.append("\t\tif let x = Mapper.unmap(\(variable.name)) {")
                output.append("\t\t\t\(dName)[\"\(key)\"] = x")
                output.append("\t\t}")

                for idx2 in(0 ..< idx).reverse() {
                    let idx3 = idx2 + 1
                    let dName = (idx2 == 0) ? "dict" : "dict\(idx2)"
                    let prevName = "dict\(idx3)"
                    output.append("\t\t\(dName)[\"\(keys[idx2])\"] = \(prevName)")
                    output.append("\t\t}")
                }
            } else {
                let nidx = idx + 1
                let nextName = (idx == 1) ? "dict" : "dict\(nidx)"
                output.append("\t\tdo {")
                output.append("\t\t\t var \(nextName) = \(dName)[\"\(key)\"] as? [String: AnyObject] ?? [String: AnyObject]()")
            }
        }
    }
    output.append("\t\treturn dict")
    output.append("\t}")

    // nscoding
    if (nscoding || classInheritence!.contains("NSCoding")) && !isStruct {
        let codingOverride = !classInheritence!.contains("NSCoding")
        let codingOverrideString = codingOverride ? "override" : ""

        // init(coder:)
        output.append("\trequired \(classAccess) init?(coder aDecoder: NSCoder) {")

        for variable in variables {
            output.append(variable.decodeCall)
        }

        if codingOverride {
            output.append("\t\tsuper.init(coder:aDecoder)")
        }
        output.append("\t}")

        // encodeWithCoder
        output.append("    \(classAccess) \(codingOverrideString) func encodeWithCoder(aCoder: NSCoder) {")
        if codingOverride {
            output.append("\t\tsuper.encodeWithCoder(aCoder)")
        }

        for variable in variables {
            output.append(variable.encodeCall)
        }

        output.append("\t}")

//         NSCopying

        if classInheritence!.contains("NSCopying") && !isStruct {
            output.append("\t\(classAccess) func copyWithZone(zone: NSZone) -> AnyObject {")
            output.append("\t\treturn NSKeyedUnarchiver.unarchiveObjectWithData(NSKeyedArchiver.archivedDataWithRootObject(self))!")
            output.append("\t}")
        }
    }
}

var inputFile: String? = nil
var outputFile: String? = nil

for (idx, arg) in Process.arguments.enumerate() {
    if idx == 0 {
        continue
    }
    switch arg {
    case "-c":
        upperCase = true
        ignoreCase = false

    case "-n":
        nullEmptyString = true

    case "-i":
        upperCase = false
        ignoreCase = true

    default:
        if inputFile == nil {
            inputFile = arg
        } else {
            outputFile = arg
        }
    }
}

let input = try! String(contentsOfFile: inputFile!).componentsSeparatedByString("\n")

var inClass = false
let classRegex = Regex("(class|struct) +([^ :]+)[ :]+(.*)\\{ *$", options: [.AnchorsMatchLines])
let endBrace = Regex("\\}")
let openBrace = Regex("\\{")
let varRegex = Regex("(?!var|let) +([^: ]+?) *: *([^ ]+) *(?:= *([^ ]+))? *(?://! *\"([^ ]+)\")?")
let dictRegex = Regex("(?!var|let) +([^: ]+?) *: *(\\[.*?:.*?\\][!?]) *(?:= *([^ ]+))? *(?://! *\"([^ ]+)\")?")
let ignoreRegex = Regex("(.*)//! *ignore", options: [.CaseInsensitive])
let awakeRegex = Regex("//! *awake", options: [.CaseInsensitive])
let codingRegex = Regex("//! *nscoding", options: [.CaseInsensitive])
let enumRegex = Regex("enum ([^ :]+)[ :]+([^ ]+)")
let accessRegex = Regex("(public|private|internal)")
var braceLevel = 0
var importRegex = Regex("import +([^ ]+)")
var inImportBlock = false
var commentRegex = Regex("^//.*$")

output.append("// ================================================================== ")
output.append("//")
let last = inputFile!.componentsSeparatedByString("/").last!
output.append("// Generated from \(last)")
output.append("//")
output.append("// DO NOT EDIT THIS FILE. GENERATED FILE, EDITS WILL BE OVERWRITTEN")
output.append("//")
output.append("// ================================================================== ")

for line in input {
    var outline = line

    let priorBraceLevel = braceLevel
    braceLevel += openBrace.numberOfMatchesIn(outline) - endBrace.numberOfMatchesIn(outline)

    if priorBraceLevel == 0 && !didImportCast {
        if let matches: [String?] = importRegex ~ line {
            if !inImportBlock {
                inImportBlock = true
            }
            if let framework = matches[1] where framework.hasPrefix("Cast") {
                didImportCast = true
            }
        } else if inImportBlock {
            inImportBlock = false
            if !didImportCast {
                didImportCast = true
                output.append("#if os(iOS)")
                output.append("import Cast")
                output.append("#elseif os(tvOS)")
                output.append("import CastTV")
                output.append("#else")
                output.append("import CastX")
                output.append("#endif")
            }
        }
    }

    if priorBraceLevel <= 1, let matches = enumRegex.matchGroups(line) {
        guard let name = matches[1] else {
            fatalError()
        }
        guard let rawType = matches[2] else {
            fatalError()
        }
        enumMapping[name] = rawType
    } else {
        if inClass {
            if braceLevel == 0 {
                inClass = false
                createFunctions()
            } else if priorBraceLevel == 1 {
                if ignoreRegex ~ line {
                    outline = line.replace(ignoreRegex, with: "$1")
                } else if awakeRegex ~ line {
                    callAwake = true
                    continue
                } else if codingRegex ~ line {
                    nscoding = true && !isStruct
                    continue
                } else if let matches: [String?] = dictRegex ~ line {
                    variables.append(VarInfo(name: matches[1]!, type: matches[2]!, defaultValue: matches[3], key: matches[4]))
                    outline = line.replace(dictRegex, with: " $1: $2")
                } else if let matches: [String?] = varRegex ~ line {
                    variables.append(VarInfo(name: matches[1]!, type: matches[2]!, defaultValue: matches[3], key: matches[4]))
                    outline = line.replace(varRegex, with: " $1: $2")
                }
            }
        } else if priorBraceLevel == 0 {
            if let matches = classRegex.matchGroups(line) {
                inClass = true
                classInheritence = matches[3]?.stringByReplacingOccurrencesOfString(" ", withString: "").componentsSeparatedByString(",")
                className = matches[2]
                variables = [VarInfo]()
                callAwake = false
                isStruct = (matches[1] == "struct")
                if let matches: [String?] = accessRegex ~ line {
                    classAccess = matches[1] ?? "internal"
                } else {
                    classAccess = "internal"
                }
                nscoding = false
            }
        }
    }

    if commentRegex ~ line {
        continue
    }

    output.append(outline)
}

try! output.joinWithSeparator("\n").writeToFile(outputFile!, atomically: true, encoding: NSUTF8StringEncoding)
