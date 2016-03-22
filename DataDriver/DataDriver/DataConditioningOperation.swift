//
//  DataConditioningOperation.swift
//  DataDriver
//
//  Created by ERIKHEATH A THOMAS on 3/15/16.
//  Copyright © 2016 Curated Cocoa LLC. All rights reserved.
//

import Foundation
import CoreData

struct DataConditionerCondition: OperationCondition {

    static let name = "DataConditioner"

    static let isMutuallyExclusive = false

    let partitionOp: RemoteStoreRequestOperation

    let contextValidator: ContextValidatorOperation

    init(partitionOp: RemoteStoreRequestOperation, contextValidator: ContextValidatorOperation) {
        self.partitionOp = partitionOp
        self.contextValidator = contextValidator
    }

    func dependencyForOperation(operation: Operation) -> NSOperation? {
        guard let operation = operation as? ContextValidatorOperation else { return nil }

        return DataConditionerOperation(partitionOp: self.partitionOp, contextValidator: operation)
    }

    func evaluateForOperation(operation: Operation, completion:OperationConditionResult -> Void) {
        switch self.contextValidator.dataConditioned  {
        case true:
            completion(.Satisfied)

        default:
            let error = NSError(code: .ConditionFailed, userInfo: [
                OperationConditionKey: self.dynamicType.name
                ])

            completion(.Failed(error))
        }
    }
}

class DataConditionerOperation: Operation {

    var dataRetrieved: Bool = false

    var dataToProcess: NSData? = nil

    let partitionOp: RemoteStoreRequestOperation

    let contextValidator: ContextValidatorOperation

    init(partitionOp: RemoteStoreRequestOperation, contextValidator: ContextValidatorOperation) {
        self.partitionOp = partitionOp
        self.contextValidator = contextValidator
    }

    override func execute() {

        defer {
            finish()
        }

        processor: do {

            let processingType = try self.validateURLResponseType()

            switch processingType {

            case .JSON:
                try JSONCollectionProcessor(operationGraphManager: self.partitionOp.graphManager, stackID: self.partitionOp.graphManager.stackID).processJSONDataStructure(self.dataToProcess!, request: self.partitionOp.URLRequest!, context: self.partitionOp.partitionContext)

            case .Image:
                try ImageDataProcessor().processImageData(self.dataToProcess!, request: self.partitionOp.URLRequest!, context: self.partitionOp.partitionContext)
            }

        } catch {
            return
        }

        self.contextValidator.dataConditioned = true
        return
    }

    // MARK: Utilities

    // MARK: Error Management
    enum DataConditionerError: Int, ErrorType {
        case missingEntity = 7000
        case missingProperty = 7001
        case missingEntityUserInfo = 7002
        case missingPropertyUserInfo = 7003
        case unknownRemoteStoreType = 7004
    }

    /**
    Supported URL response types that can be processed by the data conditioning system.
    */
    enum URLResponseProcessingType: String, CustomStringConvertible {
        case Image = "Image"
        case JSON = "JSON"

        var description:String { return self.rawValue }

    }

    /**
     Determines the type of URL Response received by interrogating the response, determining if it has the necessary components to attempt processing.

     - Throws: If a supported type can not be determined, an error is thrown.

     - Returns: A URL response processing type corresponding to the supported types.

     */
    func validateURLResponseType() throws -> URLResponseProcessingType {

        guard let entity = self.partitionOp.URLRequest?.requestEntity else {
            throw DataConditionerError.missingEntity
        }

        guard let _ = entity.userInfo else {
            throw DataConditionerError.missingEntityUserInfo
        }

        switch self.partitionOp.URLRequest?.requestProperty {

        case let targetProperty where targetProperty is NSRelationshipDescription:

            guard let _ = targetProperty?.userInfo else { throw DataConditionerError.missingPropertyUserInfo }

            return URLResponseProcessingType.JSON

        case let targetProperty where targetProperty is NSAttributeDescription:

            guard let userInfo = targetProperty?.userInfo else { throw DataConditionerError.missingPropertyUserInfo }

            switch userInfo[kRemoteStoreURLType] as? String {

            case let x where x == kRemoteStoreURLTypeImage:
                return URLResponseProcessingType.Image

            case let x where x == kRemoteStoreURLTypeFeed:
                return URLResponseProcessingType.JSON

            default:
                throw DataConditionerError.unknownRemoteStoreType
            }
            
        default:
            return URLResponseProcessingType.JSON
            
        }
    }
}