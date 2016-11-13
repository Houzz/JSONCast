# JSON Cast

We explain a bit more about JSON Cast in our [blog post]( http://blog.houzz.com/post/148054770808/a-json-parsing-class-generator).

Easily create classes from parsed JSON and conform to `NSCopying` and `NSEncoding`. In a nutshell, using JSON Cast you create a `.cast` file that is basically a Swift definition of your class properties, and Cast will create a `.swift` file from it that has the necessary `init` methods to init from JSON data or string, init from a dictionary as well as optionally `NSCoding`. Added as an Xcode build rule, so Swift files are automatically generated whenever the cast file is updated.

- Supports Swift classes and structs (`NSCoding` / `NSCopying` only supported with classes)
- Supports let and var properties
- Supports any enum type - enums backed by other types are automatically supported while any other Swift enums can be easily supported
- Automatically map JSON keys to properties based on property names, or easily add custom key mappings.
- Supports required and optional JSON keys

## Swift 3

JSON cast is ported to Swift 3, both the code it generates is Swift 3 and it is expecting the Xcode 8 runtime to be present. If you are still using Swift 2, there is a Swift 2 branch, though beware that this branch is not maintained, new developments will only go in the master branch.

## Basic Usage

Create a `.cast` file with your properties as follows:

```swift
class A: DictionaryConvertible {
    let b: Int
    let c: String?
    let d: URL //! "url"
}
```

This will create a class that conforms to the `DictionaryConvertible` protocol that is mapped from a dictionary that has a key `"b"` that holds an `Int`, which can either be a number or a string that is converted to a number. The key `"c"` is optional and may not appear in the dictionary, it holds a string value, and a key `"url"` that is mapped to the property `d` in code.

You  never need to look at the generated file; it's not important. Add your methods in a different file as an extension to class `A`.

## Install

1. clone this repository.
1. Add the Cast project to your workspace.
1. For iOS projects, link with the Cast.framework, tvOS projects need to link with CastTV.framework and OS X projects with CastX.framework
1. Add a build rule to convert *.cast files as follows:

![build rule](images/1.png "build rule") 

Do source files matching *.cast, use script and type the following:

```
${SRCROOT}/cast -c -n "$INPUT_FILE_PATH" "$DERIVED_SOURCES_DIR/$INPUT_FILE_BASE.swift"
```

In the output files, put `${DERIVED_SOURCES_DIR}/${INPUT_FILE_BASE}.swift` as the output file.


Now create the cast script, in terminal `cd` to your project `dir` and type:

```bash
ln -s path/to/cast-script/main.swift cast
```

Now try adding a `.cast` file to your project and it should compile.

### Command line options:

The cast scripts accepts the following command line options:

__-c__  or __-uppercase__  
Capitalize the key names, so a property named "age" will use the key "Age". Without the -c key names are the same as property names, that is the property "age" will use the key "age." 


__-m__ or __-noimpoert__  
Don't add an import Cast statement to the generated files. Useful if you chose to integrate by adding the mapper.swift file to your project instead of usig the cast framework

## Advanced Usage

### The Cast File 

The Cast file is a Swift class file that contains only class or struct declarations with their properties. When defining a class it should declare itself conforming to the `DictionaryConvertible` protocol. If it does not, the script assumes it inherits from a `DictionaryConvertible` conforming class and will call `super` on its methods.

The `DictionaryConvertible` protocol defines two methods: `init?(dictionary: JSONDictionary)` is an initializer from a dictionary, `JSONDictionary` is a protocol that is defined in the cast framework and that `[String: Any]` conforms to, it is failable and will return nil if the dictionary does not contain all the required keys. Any property that is defined as non-optional with no default value is assumed to be required.
It also defines a `dictionaryRepresentation()` method that returns a dictionary representing the object. Two additional convenience initialzers are defined in `DictionaryConvertible`: `init?(json: String)` and `init?(json: NSData)` that will use `NSJSONSerialization` to convert the JSON to a dictionary and call `init?(dictionary: [String: AnyObject])`.

### Properties

Each property can be defined with a `let` or `var` and must include a type. The script isn't as smart as the compiler in inferring types. You can add a default value with `= value` If you want to define a special key mapping, add the key in a comment, such as `//! "Key"` or `//! "Level1/Level2/Key"` to define a key path into the dictionary, that is the key `Level1` is assumed to contain a dictionary that has the key `Level2` which is a dicionary which has the key `Key` which contains the value.

Each property can have a default value which is assigned if the corresponding key is not found in the dictionary. Default values are provided as an initial value in Swift, e.g. `let x: String = "default"`

Properties that are defined as `optional` or properties that are not optional but have a default value are also treated as optional, meaning if the corresponding key is not found in the dictionary, the default value is used. Required properties will cause the init to fail and return `nil` if their corresponding key is missing from the dictionary.

If you annotate a property declaration with a `//! ignore` comment, it will be ignored by the Cast script and will not be included in the `NSCoding` encoding nor `init?(dictionary: JSONDictionary)`. Since extensions can't add stored properties to a class, you can use this to add stored properties which are derived from other properties, so are not in the dictionary.

Here is a summary of the different property declarations:

```swift
class AnObject: DictionaryConvertible {
    let a: Int
    let b: String?
    var c: Int = 0
    let d: [Int]  //! "Other"
    var e: URL? //! ignore
}
```

In this definition we have a readonly property `a` that will be initialized from the key `"a"` in the dictionary, and is required. If the dictionary does not have a key `"a"`, the init will fail. The property `b` is a `String` and is `optional`: if the dictionary does not have a key `"b"`, `b` will be `nil`. The read-write property `c` is an `Int`: if the dictionary does not have a key `"c"`, `c` will be assiged the default value of `0`. The property `d` will be initialized from the key `Other` in the dictionary that should contain an array of integers, and the property `e` is a derived property that will not be included in the initializer.

### Supporting Enums

RawRepresentable enums are supported by default. To support pure swift enums one needs to have the enum adopt the protocol JSONValue which has methods to convert to/from a dictionary value and in order to support NSCoding one needs to also exten the NSCoding class and add an encode/decode functions for the enum type.

### JSONValue

To enable cast to cast from JSON/ a new type, for example lets use Date (any `DictionaryConvertible` class is automatically supported) you need to extend that class to support the `JSONValue` protocol with two methods. For example, lets extend `Date` so we can use Date type properties, this implementation assumes dates are sent as integers representing the time since 1970.

```swift
extension Date: JSONValue {
    public static func value(from object: Any) -> Date? {
        switch object {
        case let x as String:
            guard let y = Int(x) else { return nil }
            return NSDate(timeIntervalSince1970: NSTimeInterval(y))

        case let x as Int:
            return NSDate(timeIntervalSince1970: NSTimeInterval(x))

        case let x as NSDate:
            return x

        default:
            return nil
        }
    }
    
    public var jsonValue: Any? {
        return timeIntervalSince1970
    }
}
```

The `value(from:)` method is used to convert from JSON to a value. Note the implementation handles both the case the JSON contains an Int and the case it contains a string with an Int, i.e. both `"date": 2` and `"date": "2"`. JSON cast works this way for all basic values, like Int, Float or Bool.

### Custom initialization

You can write a custom parser to initialize a specific property, say you have a property `let powerMode: Int`, by adding a `//! custom` comment, cast will try to call a custom function that will get the dictionary as a parameter and should return an optional of the same type as the property, in this example the following will be called: `class func parsePowerMode(from dict: JSONDictionary) -> Int?`, the custom parser should return the value if the parsing was successful, or nil if not.

=======
### Awake

The init will call an `awake(with dictionary: JSONDictionary) -> Bool` functionary passing it the dictionary that was used to initialize the object. If the function returns true the init will succeed, if it returns false the init will fail. You can use the awakeFromDictionary method to perform last value validations after the dictionary is parsed as well as compute any derived value you need or do any post processing after the dictionary is read.

### Adopting `NSCoding` and `NSCopying`

To adopt `NSCoding`, your oject has to be an Objective-C compatible object (a limitation of the `NSEncoding` protocol), so it must inherit from `NSObject`. To adopt `NSCoding`, simply add it to the list of protocols your class conforms to and the appropriate `init` and `encodeWithCoder` functions will be generated.

To adopt `NSCopying`, add it to the list of protocols your class conforms to. A `copyWithZone` function will be generated. The `NSCopying` code relies on the `NSCoding` adoption, so you must adopt `NSCoding` to support `NSCopying`.

### Inheritance

To inherit from a class that supports `DictionaryConvertible`, use the parent class name in the inheritance declaration, don't add a `DictionaryConvertible` declaration to the protocol list. By not adding a `DictionaryConvertible` declaration, the script knows that a parent class declares it and will use the approprate calls to `super` in the `init` and `dictionaryRepresentation` functions.

If you are also adopting `NSCoding` in inherited classes, don't add the `NSCoding` protocol to the protocol list, instead add a `//! nscoding` comment to the class declaration. This will cause the script to call `super` in the `NSCoding` methods.

No special action is need to support `NSCopying` in inherited classes. `NSCopying` "just" works on inherited classes, as it uses the `NSCoding` functions.

### Cast File Editing

By default, Xcode treats the `.cast` file as plain text and will not highlight its syntax. You can change that by setting it to `Swift source` in the file inspector.

![file inspector](images/2.png)

## Swift 3

JSON Cast is Swift 3 ready! If you are working with Xcode 8 beta and Swift 3 there is a Swift3 branch you can use which is compatible.

## Accessing Cast Classes from Objective C

Since the `DictionaryConvertible` defines an init method that is not visible from Objective C since it relies on the `JSONDictionary` protocol that is not an Objective C protocol, if the cast script sees a class that was defined as `@objc` it will add a convenience `init?(dictionary: [String: Any])` initializer so the class can be initialized from Objective C

## Acknolwedgment

Thanks to the great article posted [here](http://jasonlarsen.me/2015/10/16/no-magic-json-pt3.html) we've refactored JSON Cast with protocols instead of type casting which improved run time performance.


