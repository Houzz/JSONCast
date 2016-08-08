# JSON Cast

We explain a bit more about JSON Cast in our [blog post]( http://blog.houzz.com/post/148054770808/a-json-parsing-class-generator).

Easily create classes from parsed JSON and conform to `NSCopying` and `NSEncoding`. In a nutshell, using JSON Cast you create a `.cast` file that is basically a Swift definition of your class properties, and Cast will create a `.swift` file from it that has the necessary `init` methods to init from JSON data or string, init from a dictionary as well as optionally `NSCoding`. Added as an Xcode build rule, so Swift files are automatically generated whenever the cast file is updated.

- Supports Swift classes and structs (`NSCoding` / `NSCopying` only supported with classes)
- Supports let and var properties
- Supports any enum type - enums backed by other types are automatically supported while any other Swift enums can be easily supported
- Automatically map JSON keys to properties based on property names, or easily add custom key mappings.
- Supports required and optional JSON keys

## Basic Usage

Create a `.cast` file with your properties as follows:

```swift
class A: DictionaryConvertible {
    let b: Int
    let c: String?
    let d: NSURL //! "url"
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
Capitalize the key names, so a property named "age" will use the key "Age". Without the `-c`, key names are the same as property names, that is the property "age" will use the key "age." 

__-i__  or __-ignorecase__  
Case insensitive keys. The keys in the dictionary are case insensitive, so the property "age" will match the key "Age", "AGE" or any case variation.

__-n__  or __-null__  
If the `-n` command line option is specified, empty strings in the JSON (e.g. `"a": ""`) will be mapped to nil `String?` values. Without it, it will map to empty strings.

__-m__ or __-noimport__  
Don't add an `import Cast` statement to the generated files. Useful if you chose to integrate by adding the `Mapper.swift` file to your project instead of usig the Cast framework.

## Advanced Usage

### The Cast File 

The Cast file is a Swift class file that contains only class or struct declarations with their properties. When defining a class it should declare itself conforming to the `DictionaryConvertible` protocol. If it does not, the script assumes it inherits from a `DictionaryConvertible` conforming class and will call `super` on its methods.

The `DictionaryConvertible` protocol defines two methods: `init?(dictionary: [String: AnyObject])` is an initializer from a dictionary, it is failable and will return nil if the dictionary does not contain all the required keys. Any property that is defined as non-optional with no default value is assumed to be required.
It also defines a `dictionaryRepresentation()` method that returns a dictionary representing the object. Two additional convenience initialzers are defined in `DictionaryConvertible`: `init?(json: String)` and `init?(json: NSData)` that will use `NSJSONSerialization` to convert the JSON to a dictionary and call `init?(dictionary: [String: AnyObject])`.

### Properties

Each property can be defined with a `let` or `var` and must include a type. The script isn't as smart as the compiler in inferring types. You can add a default value with `= value` If you want to define a special key mapping, add the key in a comment, such as `//! "Key"` or `//! "Level1/Level2/Key"` to define a key path into the dictionary, that is the key `Level1` is assumed to contain a dictionary that has the key `Level2` which is a dicionary which has the key `Key` which contains the value.

Each property can have a default value which is assigned if the corresponding key is not found in the dictionary. Default values are provided as an initial value in Swift, e.g. `let x: String = "default"`

Properties that are defined as `optional` or properties that are not optional but have a default value are also treated as optional, meaning if the corresponding key is not found in the dictionary, the default value is used. Required properties will cause the init to fail and return `nil` if their corresponding key is missing from the dictionary.

If you annotate a property declaration with a `//! ignore` comment, it will be ignored by the Cast script and will not be included in the `NSCoding` encoding nor `init?(dictionary: [String: AnyObject])`. Since extensions can't add stored properties to a class, you can use this to add stored properties which are derived from other properties, so are not in the dictionary.

Here is a summary of the different property declarations:

```swift
class AnObject: DictionaryConvertible {
    let a: Int
    let b: String?
    var c: Int = 0
    let d: [Int]  //! "Other"
    var e: NSURL? //! ignore
}
```

In this definition we have a readonly property `a` that will be initialized from the key `"a"` in the dictionary, and is required. If the dictionary does not have a key `"a"`, the init will fail. The property `b` is a `String` and is `optional`: if the dictionary does not have a key `"b"`, `b` will be `nil`. The read-write property `c` is an `Int`: if the dictionary does not have a key `"c"`, `c` will be assiged the default value of `0`. The property `d` will be initialized from the key `Other` in the dictionary that should contain an array of integers, and the property `e` is a derived property that will not be included in the initializer.

### Supporting Enums

To add enums backed by compatible types, add the enum declaration to the `.cast` file. For example:

```swift
enum Option: Int {
    case OptionZero
    case OptionOne
}

struct AnObject: DictionaryConvertible {
    option: Option?
}
```
	
... will read the option from the dictionary for an `Option` enum backed by `Int`.

Adding support for other Swift enums requires adding an extension to the `Mapper` class to support the new type, see the Mapper extension section.

### Mapper

The generated code uses a `Mapper` class to do the mapping between dictionary values and property values. To support a new property type, add an extension to the `Mapper` class with two functions:

```swift
class func map(object: AnyObject) -> Type?
class func unmap(object: Type) -> AnyObject?
```
	
The `map` function is used when converting values in the dictionary to property values. Its given the value in the dictionary as the object argument and may return `nil` to indicate the value couldn't be converted. The funcion `unmap` does the reverse, given a value, convert it to its dictionary value. For example adding support for `NSDate` values, converting them from an `Int` representing the number of seconds since January 1970, and the `Int` can either be expressed as a number in JSON or as a string representing the number:

```swift
extension Mapper {
    class func map(object: AnyObject?) -> NSDate? {
        switch object {
        case let x as String:
            return NSDate(timeIntervalSince1970: NSTimeInterval(x)!)

        case let x as Int:
            return NSDate(timeIntervalSince1970: NSTimeInterval(x))

        case let x as NSDate:
            return x

        default:
            return nil
        }
    }
}
```

You can extend `Mapper` to support any new custom type you have. By default, `Mapper` supports any type conforming to `DictionaryConvertible`, so classes you defined in `.cast` files will automatically work as property types in other classes.



### `awakeWithDictionary`

By adding an `//! awake` comment to the class / struct declaration, the init will call `awakeWithDictionary(dict: [String: AnyObject]) -> Bool`, passing it the dictionary that was used to initialize the object. If the function returns `true`, the init will succeed, if it returns `false`, it will fail. You can use the `awakeFromDictionary` method to perform last value validations after the dictionary is parsed, as well as compute any derived value you need or do any post processing after the dictionary is read.

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


