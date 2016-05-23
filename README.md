# JSON Cast

Easily create classes from parsed JSON and conform to NSCophing and NSEncoding. In a nutshell using JSON Cast you create a .cast file that is basically a swift definition of your class properties and cast will create a .swift file from it that has the necessary init methods to init from a JSON data or string, init from a dictionary as well as optionally NSCoding. Added as an Xcode build rule so swift files are automatically generated whenever the cast file is updated.

- Supports swift class or struct (NSCoding / NSCopying only supported with classes)
- Supports let or var properties
- Supports any enum type - enums backed by other types are automatically supported while any other swift enum can be easily supported
- Automatically map JSON keys to properties based on property names, or easily add custom key mappings.
- Supports required and optional JSON keys

## Basic Usage

Create a .cast file with your properties as follows:

	class A: DictionaryConvertible {
		let b: Int
		let c: String?
		let d: NSURL // "url"
	}
	
Will create a class that confrms to the DistionaryCpnvertible porotocol that is mapped from a dictionary that has a key `"b"` that holds an Int, it can either be a number or a string that is converted to a number, the key `"c"` is optional and may not appear in the dictionary, it holds a string value, and a key `"url"` that is mapped to the property `d` in code. You need never need to look at the generated file, it's not important. Add your methods in a different file as an extension to class A.

## Install

1. clone this repository.
1. Add the Cast project to your workspace.
1. For iOS projects, link with the Cast.framework, tvOS projects need to link with CastTV.framework and OSX projects with CastX.framework
1. Add a build rule to convert *.cast files as follows:

 ![build rule](images/1.png "build rule") 
 
 Do surce files mathching *.cast, use script and type the following script:
 
    ${SRCROOT}/cast -c "$INPUT_FILE_PATH" "$DERIVED_SOURCES_DIR/$INPUT_FILE_BASE.swift"

The -c -s needed if you want to capitalize the key names, so a property named "age" will use the key "Age". Without the -c key names are the same as property names, that is the property "age" will use the key "age." In the output files put `${DERIVED_SOURCES_DIR}/${INPUT_FILE_BASE}.swift` as the output file.

Now create the cast script, in terminal cd to your project dir and type:

    ln -s path/to/cast-script/main.swift cast
    
Now try adding a .cast file to your project and it should compile.