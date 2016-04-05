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

        var requestOp: RemoteStoreRequestOperation? = nil
        for testOp in transaction.internalQueue.operations {
            guard testOp is RemoteStoreRequestOperation else { continue }
            requestOp = testOp as? RemoteStoreRequestOperation
            break
        }
        XCTAssertNotNil(requestOp)
        XCTAssert(requestOp!.conditions.count == 1)
        XCTAssertNotNil(requestOp!.conditions.first as? DataConditionerCondition)
        XCTAssert(requestOp!.dependencies.count == 2)

        var dataCondOp: DataConditionerOperation? = nil
        for testOp in requestOp!.dependencies {
            guard testOp is DataConditionerOperation else { continue }
            dataCondOp = testOp as? DataConditionerOperation
            break
        }
        XCTAssertNotNil(dataCondOp)
        XCTAssert(dataCondOp!.conditions.count == 1)
        XCTAssertNotNil(dataCondOp!.conditions.first as? RequestDataCondition)
        XCTAssert(dataCondOp!.dependencies.count == 2)

        var reqDataOp: RequestDataOperation? = nil
        for testOp in dataCondOp!.dependencies {
            guard testOp is RequestDataOperation else { continue }
            reqDataOp = testOp as? RequestDataOperation
            break
        }
        XCTAssertNotNil(reqDataOp)
        XCTAssert(reqDataOp!.conditions.count == 1)
        XCTAssertNotNil(reqDataOp!.conditions.first as? RequestConstructionCondition)
        XCTAssert(dataCondOp!.dependencies.count == 2)

        var reqConOp: RequestConstructionOperation? = nil
        for testOp in reqDataOp!.dependencies {
            guard testOp is RequestConstructionOperation else { continue }
            reqConOp = testOp as? RequestConstructionOperation
            break
        }
        XCTAssertNotNil(reqConOp)
        XCTAssert(reqConOp!.conditions.count == 1)
        XCTAssertNotNil(reqConOp!.conditions.first as? RequestValidationCondition)
        XCTAssert(reqConOp!.dependencies.count == 2)

        var reqValOp: RequestValidation? = nil
        for testOp in reqConOp!.dependencies {
            guard testOp is RequestValidation else { continue }
            reqValOp = testOp as? RequestValidation
            break
        }
        XCTAssertNotNil(reqValOp)
        XCTAssert(reqValOp!.conditions.count == 0)
        XCTAssertNil(reqValOp!.conditions.first)
        XCTAssert(reqValOp!.dependencies.count == 1)

    }

    
}
