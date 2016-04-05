//
//  TransactionOperationTests.swift
//  DataDriver
//
//  Created by ERIKHEATH A THOMAS on 4/5/16.
//  Copyright © 2016 Curated Cocoa LLC. All rights reserved.
//

import XCTest
import CoreData

@testable import DataDriver

class TransactionOperationTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testInitialization() {
        let testStore = StoreReference(storeType: NSInMemoryStoreType, configuration: nil, URL: nil, options: nil)
        let testModel = NSManagedObjectModel()
        let dataLayerOne: DataLayer

        do {
            dataLayerOne = try DataLayer(stores: [testStore], model: testModel, preload: nil, stackID: nil, delegate: nil)
        } catch {
            XCTFail("Unable to load model")
            return
        }

        XCTAssertNotNil(dataLayerOne)
        XCTAssertNotNil(dataLayerOne.persistentStoreCoordinator)
        XCTAssertNotNil(dataLayerOne.persistentStores)
        XCTAssertNil(dataLayerOne.delegate)
        XCTAssertNotNil(dataLayerOne.stackID)
        XCTAssertNil(dataLayerOne.preloadFetch)
        XCTAssertNotNil(dataLayerOne.masterContext)
        XCTAssertNotNil(dataLayerOne.mainContext)
        XCTAssertNotNil(dataLayerOne)
        XCTAssertNotNil(dataLayerOne.persistentStoreCoordinator.operationGraphManager)
        XCTAssertNotNil(dataLayerOne.persistentStoreCoordinator.operationGraphManager.fetchRequests)
        XCTAssertNotNil(dataLayerOne.persistentStoreCoordinator.operationGraphManager.queue)
        XCTAssertEqual(dataLayerOne.persistentStoreCoordinator.operationGraphManager.stackID, dataLayerOne.stackID)

        // Create a transaction off of the operation graph queue to inspect the internals
        dataLayerOne.persistentStoreCoordinator.operationGraphManager.queue.suspended = true
        let request = NetworkStoreFetchRequest()
        let transaction = TransactionOperation(request: request, graphManager: dataLayerOne.persistentStoreCoordinator.operationGraphManager)
        XCTAssertNotNil(transaction.internalQueue)
        XCTAssert(transaction.internalQueue.operationCount == 6)
    }

    
}
