#!/usr/bin/env -i xcrun -sdk macosx swift -swift-version 3
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
var houzzLogging = false
var disableHouzzzLogging = false
var generateDefaultInit = false
var classWantsDefaultInit = false
var awakeFromRead = false
var superTag: String? = nil

class Regex {
    private let expression: NSRegularExpression
    private var match: NSTextCheckingResult?

    init(_ pattern: String, options: NSRegularExpression.Options = []) {
        self.expression = try! NSRegularExpression(pattern: pattern, options: options)
    }

    func matchGroups(_ input: String) -> [String?]? {
        match = expression.firstMatch(in: input, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, input.count))
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
        match = expression.firstMatch(in: input, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, input.count))
        return match != nil
    }

    func replace(_ input: String, with template: String) -> String {
        return expression.stringByReplacingMatches(in: input, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, input.count), withTemplate: template)
    }

    func numberOfMatchesIn(_ input: String) -> Int {
        return expression.matches(in: input, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, input.count)).count
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
        return String(self[range])
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
    let useCustomParse: Bool
    let skip: Bool

    init(name: String, isLet: Bool, type: String, defaultValue: String? = nil, asIsKey: Bool, key in_key: String? = nil, useCustom: Bool = false, skip: Bool = false) {
        self.name = name
        self.isLet = isLet
        self.skip = skip
        useCustomParse = useCustom
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
                let correctCaseKey: String = $0.trimmingCharacters(in: CharacterSet.whitespaces)
                if upperCase && !asIsKey {
                    return "\(correctCaseKey[0].uppercased())\(correctCaseKey[1 ..< correctCaseKey.count])"
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
            if optional {
                vv = "\(name)?"
            }

            ret += "\(vv).encode(with: aCoder, forKey: \"\(name)\")"

            return ret
        }
    }

    var decodeCall: String {
        get {

            var v: String
                v = "if let v = \(type).decode(with: aDecoder, fromKey:\"\(name)\") {"
                v += "\n\t\t\t\(name) = v"
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
        guard skip == false else {
            return
        }
        var assignments: [String]
        if useCustomParse {
            let caseName = "\(name[0].uppercased())\(name[1 ..< name.count])"
            assignments = [ "\(className!).parse\(caseName)(from: dict)"]
        } else {
            assignments = key.map { "dict.value(for: \"\($0)\")" }
        }
        if doNil {
        if let defaultValue = defaultValue {
            assignments.append("\(defaultValue)")
        }
        }
        let assignExpr = assignments.joined(separator: " ?? ")
        if (optional || isNullable || defaultValue != nil) && doNil {
            output.append("\t\t\(name) = \(assignExpr)")
        } else {
            output.append("\t\tif let v:\(type) = \(assignExpr) {")
            output.append("\t\t\t\(name) = v")
            output.append("\t\t}")
            if doNil {
                output.append(" else {")
                if houzzLogging && !disableHouzzzLogging {
                    output.append("LogError(\"Error: \(className!).\(name) failed init\")")
                }
                output.append("   return nil")
                output.append(" }")
            }
        }
    }

    func getInitParam() -> String? {
        if skip {
            return nil
        }
        let optPart = optional || self.isNullable ? "?" : ""
        let defaultValue = self.defaultValue ?? (self.optional  ? "nil" : nil)
        return "\(name): \(type)\(optPart)" + (defaultValue.map { " = " + $0 } ?? "")
    }

    func getInitAssign() -> String {
        return "\t\tself.\(name) = \(name)"
    }
}
var variables = [VarInfo]()

func createFunctions() {
    var override = ""
    if classInheritence == nil {
        classInheritence = [String]()
    }
    if !classInheritence!.contains("DictionaryConvertible") && !isStruct {
        override = "override"
    }

    // init
    let reqStr = isStruct ? "" : "required"
    let initAccess =  classAccess == "open" ? "public" : classAccess

    output.append("\(reqStr) \(initAccess) init?(dictionary dict: JSONDictionary) {")

    for variable in variables {
        if variable.skip {
            continue
        }
        variable.generateRead(nilMissing: true)
    }


    if !override.isEmpty {
        if let superTag = superTag {
            output.append("guard let superDict = dict.any(forKeyPath: \"\(superTag)\") as? JSONDictionary else {")
            output.append("return nil")
            output.append("}")
            output.append("super.init(dictionary: superDict)")
        } else {
            output.append("\t\tsuper.init(dictionary: dict)")
        }
    } else if classInheritence!.contains("DictionaryConvertible") && classInheritence![0] != "DictionaryConvertible" && !isStruct && override.isEmpty {
        output.append("\t\tsuper.init()")
    }
    if override == "" {
        output.append("\t\t\tif !awake(with: dict) { return nil }")
    }
    output.append("\t}")

    // init(values...)
    if generateDefaultInit || classWantsDefaultInit {
        let params = variables.flatMap { return $0.getInitParam() }.joined(separator: ", ")
        output.append("\t\(initAccess) init(\(params)) {")
        for variable in variables {
            if variable.skip == false {
            output.append(variable.getInitAssign())
            }
        }
        output.append("\t}")
    }

    // read(from:)
    if generateRead {
        output.append("\(override) \(classAccess) func read(from dict: JSONDictionary) {")

        for variable in variables {
            if !variable.isLet {
                variable.generateRead(nilMissing: false)
            }
        }

        if !override.isEmpty {
            if let superTag = superTag {
                output.append("guard let superDict = dict.any(forKeyPath: \"\(superTag)\") as? JSONDictionary else {")
                output.append("return")
                output.append("}")
                output.append("super.read(from: superDict)")
            } else {
                output.append("\t\tsuper.read(from: dict)")
            }
        }
        
        if awakeFromRead {
            output.append("\t\t\t let _ = awake(with: dict)")
        }
        output.append("\t\t}")
    }


    // dictionaryRepresentation()

    output.append("\t\(isObjc ? "@objc" : "") \(override) \(classAccess) func dictionaryRepresentation() -> [String: Any] {")
    if override.isEmpty {
        output.append("\t\tvar dict = [String: Any]()")
    } else {
        if let superTag = superTag {
            output.append("\t\tvar dict:[String:Any] = [\"\(superTag)\": super.dictionaryRepresentation()]")
        } else {
            output.append("\t\tvar dict = super.dictionaryRepresentation()")
        }
    }


    for variable in variables {
        if variable.skip {
            continue;
        }
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
                let nextName =  "dict\(nidx)"
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
        output.append("\trequired \(initAccess) init?(coder aDecoder: NSCoder) {")

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
        output.append("\t@objc convenience init?(dictionary: [String: Any]) {")
        output.append("\t\tself.init(dictionary: dictionary as JSONDictionary)")
        output.append("\t}")
        if generateRead {
        output.append("@objc func read(from dict: [String: Any]) {")
        output.append(" read(from: dict as JSONDictionary)")
        output.append("}")
        }
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

    case "-houzz":
        houzzLogging = true

    case "-init":
        generateDefaultInit = true

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
let varRegex = Regex("(var|let) +([^: ]+?) *: *([^ ]+) *(?:= *([^ ]+))? *(?://! *(v?)\"([^\"]+)\")?(?://! *(custom))?")
let skipVarRegex = Regex("(var|let) +([^: ]+?) *: *([^ ]+) *(?:= *([^ ]+))? *//! *ignore json")
let dictRegex = Regex("(var|let) +([^: ]+?) *: *(\\[.*?:.*?\\][!?]) *(?:= *([^ ]+))? *(?://! *(v?)\"([^ ]+)\")?(?://! *(custom))?")
let ignoreRegex = Regex("(.*)//! *ignore", options: [.caseInsensitive])
let codingRegex = Regex("//! *nscoding", options: [.caseInsensitive])
let enumRegex = Regex("enum ([^ :]+)[ :]+([^ ]+)")
let accessRegex = Regex("(public|private|internal|open)")
var braceLevel = 0
var importRegex = Regex("import +([^ ]+)")
var inImportBlock = false
var commentRegex = Regex("^ *//[^!].*$")
let disableLogging = Regex("//! *nolog")
let classInit = Regex("//! +init\\b")
let awakeFromReadRegex = Regex("//! +awakeFromRead\\b")
let superTagRegex = Regex("//! +super +\"([^\"]+)\"")

output.append("// ================================================================== ")
output.append("//")
let last = inputFile!.components(separatedBy: "/").last!
output.append("// Generated from \(last)")
output.append("//")
output.append("// DO NOT EDIT THIS FILE. GENERATED FILE, EDITS WILL BE OVERWRITTEN")
output.append("//")
output.append("// ================================================================== ")

for line in input {
    if commentRegex.match(line) {
        continue
    }

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
                if ignoreRegex.match(line) && !skipVarRegex.match(line) {
                    outline = line.replace(ignoreRegex, with: "$1")
                } else if codingRegex.match(line) {
                    nscoding = true && !isStruct
                    continue
                } else if classInit.match(line){
                    classWantsDefaultInit = true
                    continue
                } else if awakeFromReadRegex.match(line){
                    awakeFromRead = true
                    continue
                } else if disableLogging.match(line) {
                    disableHouzzzLogging = true
                    continue
                } else if let matches: [String?] = skipVarRegex.matchGroups(line) {
                    variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], asIsKey: true, key: nil, useCustom: false, skip: true))
                    outline = line
               } else if let matches: [String?] = dictRegex.matchGroups(line) {
                    variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], asIsKey: !(matches[5]?.isEmpty ?? true), key: matches[6], useCustom: matches[7] != nil))
                    outline = line.replace(dictRegex, with: " $1 $2: $3")
                } else if let matches: [String?] = varRegex.matchGroups(line) {
                    variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], asIsKey: !(matches[5]?.isEmpty ?? true), key: matches[6], useCustom: matches[7] != nil))
                    outline = line.replace(varRegex, with: " $1 $2: $3")
                 } else if let matches: [String?] = superTagRegex.matchGroups(line) {
                    if let str = matches[1] {
                        superTag = str
                    }
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
                    classAccess = matches[1] ?? ""
                } else {
                    classAccess = ""
                }
                nscoding = false
                disableHouzzzLogging = false
                classWantsDefaultInit = false
                superTag = nil
            }
        }
    }

     output.append(outline)
}

try! output.joined(separator: "\n").write(toFile: outputFile!, atomically: true, encoding: String.Encoding.utf8)
