#!/usr/bin/env -i xcrun -sdk macosx swift
// Copyright © 2016 Houzz. All rights reserved.

import Foundation

var classInheritence: [String]?
var className: String?
var output = [String]()
var nscoding = false
var upperCase = false
var enumMapping = [String: String]()
var isStruct = false
var classAccess = ""
var didImportCast = false
var nullEmptyString = false
var doImport = true
var generateRead = false
var isObjc = false

let encodeMap = [
    "Bool": ("aCoder.encode(Bool(%@), forKey: \"%@\")", "aDecoder.decodeBool(forKey:\"%@\")"),
    "Float": ("aCoder.encode(Float(%@), forKey: \"%@\")", "aDecoder.decodeFloat(forKey:\"%@\")"),
    "Double": ("aCoder.encode(Double(%@), forKey: \"%@\")", "aDecoder.decodeDouble(forKey:\"%@\")"),
    "CGFloat": ("aCoder.encode(Double(%@), forKey: \"%@\")", "CGFloat(aDecoder.decodeDouble(forKey:\"%@\"))"),
    "Int": ("aCoder.encode(Int(%@), forKey: \"%@\")", "aDecoder.decodeInteger(forKey:\"%@\")"),
    "UInt": ("aCoder.encode(Int(%@), forKey: \"%@\")", "UInt(aDecoder.decodeInteger(forKey:\"%@\"))")
]

class Regex {
    private let expression: NSRegularExpression
    private var match: NSTextCheckingResult?
    
    init(_ pattern: String, options: NSRegularExpression.Options = []) {
        self.expression = try! NSRegularExpression(pattern: pattern, options: options)
    }
    
    func matchGroups(_ input: String) -> [String?]? {
        match = expression.firstMatch(in: input, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, input.characters.count))
        if let match = match {
            var captures = [String?]()
            for group in 0 ..< match.numberOfRanges {
                let r = match.rangeAt(group)
                if r.location != NSNotFound {
                    let stringMatch = (input as NSString).substring(with: match.rangeAt(group))
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
    
    func match(_ input: String) -> Bool {
        match = expression.firstMatch(in: input, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, input.characters.count))
        return match != nil
    }
    
    func replace(_ input: String, with template: String) -> String {
        return expression.stringByReplacingMatches(in: input, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, input.characters.count), withTemplate: template)
    }
    
    func numberOfMatchesIn(_ input: String) -> Int {
        return expression.matches(in: input, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, input.characters.count)).count
    }
}

extension String {
    func replace(_ regex: Regex, with template: String) -> String {
        return regex.replace(self, with: template)
    }

     subscript(index: Int) -> String {
        return String(self[self.index(self.startIndex, offsetBy: index)])
    }

     subscript(integerRange: Range<Int>) -> String {
        let start = self.index(self.startIndex, offsetBy: integerRange.lowerBound)
        let end = self.index(self.startIndex, offsetBy: integerRange.upperBound)
        let range = start ..< end
        return self[range]
    }
}

struct VarInfo {
    let name: String
    let type: String
    let defaultValue: String?
    let key: [String]
    var optional: Bool
    let isNullable: Bool
    let isLet: Bool
    
    init(name: String, isLet: Bool, type: String, defaultValue: String? = nil, key in_key: String? = nil) {
        self.name = name
        self.isLet = isLet
        if type.hasSuffix("?") || type.hasSuffix("!") {
            self.isNullable = true
            self.type = type.trimmingCharacters(in: CharacterSet(charactersIn: "!?"))
            self.optional = type.hasSuffix("?")
        } else {
            self.type = type
            self.optional = false
            self.isNullable = false
        }

        self.key = (in_key ?? name).components(separatedBy: "??").map {
            return $0.components(separatedBy: "/").map({
            var correctCaseKey: String = $0.trimmingCharacters(in: CharacterSet.whitespaces)
            if upperCase {
                return "\(correctCaseKey[0].uppercased())\(correctCaseKey[1 ..< correctCaseKey.characters.count])"
            }
            return correctCaseKey
            }).joined(separator:"/")
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
                ret += "aCoder.encode(\(vv), forKey: \"\(name)\")"
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
                v = "\t\tif aDecoder.containsValue(forKey:\"\(name)\") { let v = \(enc)"
            } else {
                v = "if let v = aDecoder.decodeObject(forKey:\"\(name)\") as? \(vtype) {"
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

    func generateRead(nilMissing doNil: Bool) {
        var assignments = key.map { "dict.value(for: \"\($0)\")" }
        if let defaultValue = defaultValue {
            assignments.append("\(defaultValue)")
        }
        let assignExpr = assignments.joined(separator: " ?? ")
        if optional || isNullable || defaultValue != nil {
            output.append("\t\t\(name) = \(assignExpr)")
        } else {
            output.append("\t\tif let v:\(type) = \(assignExpr) {")
            output.append("\t\t\t\(name) = v")
            output.append("\t\t}")
            if doNil {
                output.append(" else { return nil }")
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
    

        output.append("\(reqStr) \(classAccess) init?(dictionary dict: JSONDictionary) {")

    for variable in variables {
        variable.generateRead(nilMissing: true)
    }
    
    if !override.isEmpty {
        output.append("\t\tsuper.init(dictionary: dict)")
    }


        if classInheritence!.contains("DictionaryConvertible") {
            output.append("\t\tsuper.init()")
        }
        output.append("\t\tif !awake(with: dict) { return nil }")

    output.append("\t}")

    // read(from:)
    if generateRead {
            output.append("\(override) \(classAccess) func read(from dict: [String: Any]) {")

        for variable in variables {
            if !variable.isLet {
                variable.generateRead(nilMissing: false)
            }
        }

        if !override.isEmpty {
            output.append("\t\tsuper.read(from: dict)")
        }

        output.append("\t\t}")
    }

    
    // dictionaryRepresentation()
    output.append("\t\(override) \(classAccess) func dictionaryRepresentation() -> [String: Any] {")
    if override.isEmpty {
        output.append("\t\tvar dict = [String: Any]()")
    } else {
        output.append("\t\tvar dict = super.dictionaryRepresentation()")
    }


    for variable in variables {
        let optStr = variable.optional ? "?" : ""
        let keys = variable.key.first!.components(separatedBy: "/")
        for (idx, key) in keys.enumerated() {
            let dName = (idx == 0) ? "dict" : "dict\(idx)"
            if idx == keys.count - 1 {
                output.append("\t\tif let x = \(variable.name)\(optStr).jsonValue {")
                output.append("\t\t\t\(dName)[\"\(key)\"] = x")
                output.append("\t\t}")
                
                for idx2 in(0 ..< idx).reversed() {
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
                output.append("\t\t\t var \(nextName) = \(dName)[\"\(key)\"] as? [String: Any] ?? [String: Any]()")
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
        output.append("    \(classAccess) \(codingOverrideString) func encode(with aCoder: NSCoder) {")
        if codingOverride {
            output.append("\t\tsuper.encode(with: aCoder)")
        }
        
        for variable in variables {
            output.append(variable.encodeCall)
        }
        
        output.append("\t}")
        
        //         NSCopying
        
        if classInheritence!.contains("NSCopying") && !isStruct {
            output.append("\t\(classAccess) func copy(with zone: NSZone? = nil) -> Any {")
            output.append("\t\treturn NSKeyedUnarchiver.unarchiveObject(with: NSKeyedArchiver.archivedData(withRootObject: self))!")
            output.append("\t}")
        }
    }

    if isObjc && override.isEmpty {
        // class was declard @objc and is a base class not inhereting from other DictionaryConvertible classes
        output.append("\tconvenience init?(dictionary: [String: Any]) {")
        output.append("\t\tself.init(dictionary: dictionary as JSONDictionary)")
        output.append("\t}")
    }
}

var inputFile: String? = nil
var outputFile: String? = nil

for (idx, arg) in CommandLine.arguments.enumerated() {
    if idx == 0 {
        continue
    }
    switch arg {
    case "-c", "-upper", "-uppercase":
        upperCase = true

    case "-n", "-null", "-nullempty":
        nullEmptyString = true

    case "-m", "-noimport":
        doImport = false

        case "-r", "-read":
        generateRead = true
        
    default:
        if inputFile == nil {
            inputFile = arg
        } else {
            outputFile = arg
        }
    }
}

let input = try! String(contentsOfFile: inputFile!).components(separatedBy: "\n")

var inClass = false
let classRegex = Regex("(class|struct) +([^ :]+)[ :]+(.*)\\{ *$", options: [.anchorsMatchLines])
let endBrace = Regex("\\}")
let openBrace = Regex("\\{")
let varRegex = Regex("(var|let) +([^: ]+?) *: *([^ ]+) *(?:= *([^ ]+))? *(?://! *\"([^\"]+)\")?")
let dictRegex = Regex("(var|let) +([^: ]+?) *: *(\\[.*?:.*?\\][!?]) *(?:= *([^ ]+))? *(?://! *\"([^ ]+)\")?")
let ignoreRegex = Regex("(.*)//! *ignore", options: [.caseInsensitive])
let codingRegex = Regex("//! *nscoding", options: [.caseInsensitive])
let enumRegex = Regex("enum ([^ :]+)[ :]+([^ ]+)")
let accessRegex = Regex("(public|private|internal)")
var braceLevel = 0
var importRegex = Regex("import +([^ ]+)")
var inImportBlock = false
var commentRegex = Regex("^//.*$")

output.append("// ================================================================== ")
output.append("//")
let last = inputFile!.components(separatedBy: "/").last!
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
        if let matches: [String?] = importRegex.matchGroups(line) {
            if !inImportBlock {
                inImportBlock = true
            }
            if let framework = matches[1] , framework.hasPrefix("Cast") {
                didImportCast = true
            }
        } else if inImportBlock {
            inImportBlock = false
            if !didImportCast {
                didImportCast = true
                if doImport {
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
                if ignoreRegex.match(line) {
                    outline = line.replace(ignoreRegex, with: "$1")
                } else if codingRegex.match(line) {
                    nscoding = true && !isStruct
                    continue
                } else if let matches: [String?] = dictRegex.matchGroups(line) {
                    variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], key: matches[5]))
                    outline = line.replace(dictRegex, with: " $1 $2: $3")
                } else if let matches: [String?] = varRegex.matchGroups(line) {
                    variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], key: matches[5]))
                    outline = line.replace(varRegex, with: " $1 $2: $3")
                }
            }
        } else if priorBraceLevel == 0 {
            if let matches = classRegex.matchGroups(line) {
                inClass = true
                classInheritence = matches[3]?.replacingOccurrences(of: " ", with: "").components(separatedBy: ",")
                className = matches[2]
                variables = [VarInfo]()
                isStruct = (matches[1] == "struct")
                isObjc = line.contains("@objc")
                if let matches: [String?] = accessRegex.matchGroups(line) {
                    classAccess = matches[1] ?? "internal"
                } else {
                    classAccess = "internal"
                }
                nscoding = false
            }
        }
    }
    
    if commentRegex.match(line) {
        continue
    }
    
    output.append(outline)
}

try! output.joined(separator: "\n").write(toFile: outputFile!, atomically: true, encoding: String.Encoding.utf8)
