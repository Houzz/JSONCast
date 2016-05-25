//
//  CastingAppTests.swift
//  CastingAppTests
//
//  Created by Guy on 21/05/2016.
//  Copyright © 2016 Houzz. All rights reserved.
//

import XCTest
@testable import CastingApp

class CastingAppTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testEncode() {
        let an = Classy(dictionary: ["X": 3])
        XCTAssert(an == nil)

        let a = Classy(dictionary: ["X": 3, "PowerMode": "0"])!

        XCTAssert(a.x == 3)
        XCTAssert(a.why == nil)
        XCTAssert(a.y == "as")
        XCTAssert(a.powerMode == 0)
        XCTAssert(a.u == nil)
        let dict = a.dictionaryRepresentation()
        XCTAssert(dict["X"] as! Int == 3)

        let b = Classz(dictionary: [
            "X": "3",
            "Arg": "word",
            "PowerMode": 3,
            "Why": "maybe",
            "U": "http://houzz.com",
            "outer": ["inner": 4],
            "A": ["1", 2, 3],
            "Cx": ["Name": "Joe", "Age": 15],
            "Another": "another",
            "D": ["k": "v", "k2": "3"],
            "D2": ["k": "v", "k2": 3]])!
        XCTAssert(b.x == 3)
        XCTAssert(b.a! == [1, 2, 3])
        XCTAssert(b.cx?.age == 15)
        XCTAssert(b.why! == .maybe)
        XCTAssert(b.y! == "word")
        XCTAssert(b.powerMode == 3)
        XCTAssert(b.u!.absoluteString == "http://houzz.com")
        XCTAssert(b.nested! == 4)
        XCTAssert(b.another == "another")
        XCTAssert(b.d!["k"] == "v")
        XCTAssert(b.d2!["k2"] as! Int == 3)
        let dict2 = b.dictionaryRepresentation()
        XCTAssert(dict2["X"] as! Int == 3)
        XCTAssert((dict2["U"] as! NSURL) == NSURL(string: "http://houzz.com"))

        let d = b.copy() as! Classz
        XCTAssert(b.x == d.x)
        XCTAssert(b.u == d.u)

        let e = Classz(dictionary: dict2)!
        XCTAssert(b.x == e.x)
        XCTAssert(b.u == e.u)
        XCTAssert(e.nested! == 4)
    }

    func testJson() {
        let a = Classx(json: "{ \"Name\": \"Donald\", \"Age\": 60 }")!
        XCTAssert(a.age == 60)
    }

    
}
