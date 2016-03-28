//
//  StoreReferenceTests.swift
//  DataDriver
//
//  Created by ERIKHEATH A THOMAS on 3/27/16.
//  Copyright © 2016 Curated Cocoa LLC. All rights reserved.
//

import XCTest
import CoreData

@testable import DataDriver

class StoreReferenceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }


    func testInitialization() {

        let testConfiguration = "UserConfiguration"
        let testURL = NSURL(string: "http://www.apple.com")
        let testOptions = Dictionary<NSObject, AnyObject>()

        let testInMemoryStoreType = StoreReference(storeType: NSInMemoryStoreType, configuration: testConfiguration, URL: testURL, options: testOptions)
        XCTAssertEqual(testInMemoryStoreType.storeType, NSInMemoryStoreType)
        XCTAssertEqual(testInMemoryStoreType.configuration!, testConfiguration)
        XCTAssert((testInMemoryStoreType.options! as NSDictionary).isEqualToDictionary(testOptions), "Options should be equal")

        let testSQLiteStoreType = StoreReference(storeType: NSSQLiteStoreType, configuration: nil, URL: testURL, options: nil)
        XCTAssertEqual(testSQLiteStoreType.storeType, NSSQLiteStoreType)
        XCTAssertNil(testSQLiteStoreType.configuration)
        XCTAssertNotNil(testSQLiteStoreType.URL)
        XCTAssertNil(testSQLiteStoreType.options)


        let testBinaryStoreType = StoreReference(storeType: NSBinaryStoreType, configuration: nil, URL: nil, options: nil)
        XCTAssertEqual(testBinaryStoreType.storeType, NSBinaryStoreType)
        XCTAssertNil(testBinaryStoreType.URL)
    }
}
