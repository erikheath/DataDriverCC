//
//  JSONCollectionProcessor.swift
//


import CoreData


public class JSONCollectionProcessor: NSObject {

    public enum JSONParserError: Int, ErrorType {
        case formatError = 6000
        case expectedAttributeValueError = 6001
        case expectedAttributeError = 6002
        case expectedAttributeTypeError = 6003
        case expectedInverseRelationshipError = 6004
        case missingUserInfoDictionary = 6005
        case missingUserInfoValue = 6008
        case missingJSONRootKeyPath = 6006
        case missingEntity = 6007
        case missingData = 6009
        case missingBatchCount = 6010
        case missingObjectError = 6011
        case missingContext = 6012
        case missingAttributes = 6013
        case structureError = 6020
    }

    private var transaction: TransactionOperation

    private var stackID: String

    init(transaction: TransactionOperation, stackID: String) {
        self.stackID = stackID
        self.transaction = transaction
    }

    /**
     Processes the incoming data as a JSON compliant collection.

     - Parameter responseData: The data that should be converted to a JSON collection.

     - Parameter request: The request that generated the response data.

     - Parameter context: The context that should be used to create and update objects referred to in the response data.

     - Returns: An array of managed object IDs that were affected by the processing of the response data.

     - Throws: In the event of an error, typically a JSON Processing Error, Managed Object error, etc., depending on the stage of processing.
     */

    func processJSONDataStructure(responseData: NSData, request: NSURLRequest, context: NSManagedObjectContext) throws -> Array<NSManagedObjectID> {

        guard let entity = request.requestEntity else {
            throw JSONParserError.missingEntity
        }

        let rawJSON: AnyObject
        do {
            rawJSON = try NSJSONSerialization.JSONObjectWithData(responseData, options:NSJSONReadingOptions.init(rawValue: 0))
        } catch {
            throw error
        }

        return try self.processJSONCollection(self.normalizeJSONCollection(rawJSON, request: request), entity: entity, context: context, request: request)

    }

    /**
     Normalizes the collection by traversing the input collection using a JSON root key path contained in either a property description or entity description.

     - Parameter collection: The collection that should be normalized.

     - Parameter request: The request that generated the data used to create the incoming JSON collection.

     - Returns: An array of Dictionaries representing objects to add or update.

     - Throws: In the event of an error, typically a missing user info or JSON structure error.
     */
    func normalizeJSONCollection (collection: AnyObject, request: NSURLRequest ) throws -> Array<Dictionary<NSObject, AnyObject>> {

        let conditionedInfo: NSDictionary

        if let conditioned = request.requestProperty?.userInfo {
            conditionedInfo = conditioned
        } else if let conditioned = request.requestEntity?.userInfo {
            conditionedInfo = conditioned
        } else {
            throw JSONParserError.missingUserInfoDictionary
        }

        guard var rootKeyPath = conditionedInfo[kJSONRootKeyPath] as? String else {
            throw JSONParserError.missingUserInfoValue
        }

        if rootKeyPath == "CURRENTROOT" {
            rootKeyPath = ""
        }

        var dataStructure:AnyObject = collection.valueForKeyPath(rootKeyPath) ?? collection

        //        if let reroot = conditionedInfo[kRerootJSONSource] as? NSString where reroot.boolValue == true {
        //
        //        }

        switch dataStructure {

        case is NSDictionary, is Dictionary<NSObject, AnyObject>:
            dataStructure = [dataStructure as! Dictionary<NSObject, AnyObject>]

        case is NSArray, is Array<Dictionary<NSObject, AnyObject>>:
            dataStructure = dataStructure as! Array<Dictionary<NSObject, AnyObject>>

        default:
            throw JSONParserError.structureError
        }

        return dataStructure as! Array<Dictionary<NSObject, AnyObject>>

    }

    /**
     Processes the JSON collection to create and/or update objects in the passed in context based on the passed in entity. This method calls out to registered object conditioners prior to parsing each JSON object representation.

     - Parameter collection: An array of Dictionary objects representing the objects of the passed in entity type to be created.

     - Parameter entity: The entity upon which to base the newly created objects.

     - Parameter context: The context the objects should be saved to.

     - Parameter request: The request that generated the data for the JSON data.

     - Returns: An array of managed object IDs for the changed objects.

     - Throws: In the event of an error, typically a managed object context error, JSON parsing error, etc.

     */
    func processJSONCollection( collection: Array<Dictionary<NSObject, AnyObject>>, entity: NSEntityDescription, context: NSManagedObjectContext, request: NSURLRequest ) throws -> Array<NSManagedObjectID> {

        var objectIDArray: Array<NSManagedObjectID> = Array()

        let conditionedCollection = JSONObjectDataConditionerFactory.conditionObjects(collection, entity: entity)

        for JSONObject:Dictionary<NSObject, AnyObject> in conditionedCollection {

            var managedObject:NSManagedObject? = nil

            if let _ = request.destinationObjectID {
                managedObject = context.objectWithID(request.destinationObjectID!)
            } else {
                managedObject = try self.managedObjectForRemoteStore(JSONObject, entity: entity, context: context)
            }

            guard let _ = managedObject else { throw JSONParserError.structureError }

            try JSONEntityProcessor(transaction: self.transaction, stackID: self.stackID).fulfillManagedObject(managedObject!, valueSource: JSONObject, parentRelationship: nil)

            objectIDArray.append(managedObject!.objectID)

        }

        return objectIDArray

    }


    /**
     Searches for an existing remote store object. In the event that one can not be found, creates and returns a new one based on the passed in entity.

     - Parameter valueSource: The data to search when looking for a local identifier to use when searching the local store for an existing object.

     - Parameter entity: The NSEntityDescription that should be used to create the managed object.

     - Parameter context: The context in which the managed object should be inserted.

     - Returns: A new managed object associated with the passed in context that has a permanent id.

     - Throws: If a permanent id can not be created, throws the resulting managed object context error. Will also throw if a fetch request can not be executed.

     - Returns: An existing or new managed object for an object in the remote store.
     */
    func managedObjectForRemoteStore(valueSource:NSDictionary?, entity:NSEntityDescription, context:NSManagedObjectContext) throws -> NSManagedObject {

        do {
            var managedObject:NSManagedObject?

            guard let valueSource = valueSource else { throw JSONParserError.expectedAttributeError }
            guard let modelEntityID = (entity.userInfo?[kModelEntityID] as? String) else {
                throw JSONParserError.missingData
            }

            if modelEntityID != "AUTOGENERATEKEY" {
                guard let keyPath:String = entity.userInfo?[kEntityID] as? String,
                    let propertyID:String = valueSource.valueForKey(keyPath) as? String where entity.name != nil else {
                        throw JSONParserError.missingData
                }

                let request = NSFetchRequest(entityName: entity.name!)
                request.sortDescriptors = [NSSortDescriptor(key: modelEntityID, ascending: false)]

                let leftExpression = NSExpression(forKeyPath: modelEntityID)
                let rightExpression = NSExpression(forConstantValue: propertyID)

                request.predicate = NSComparisonPredicate(leftExpression:leftExpression , rightExpression: rightExpression, modifier: NSComparisonPredicateModifier.DirectPredicateModifier, type: NSPredicateOperatorType.EqualToPredicateOperatorType, options:NSComparisonPredicateOptions(rawValue: 0))

                var results: Array<AnyObject> = Array()
                var fetchError: ErrorType? = nil
                do {
                    results = try context.executeFetchRequest(request)
                } catch {
                    fetchError = error
                }

                if fetchError != nil { }
                managedObject = (results as NSArray).firstObject as? NSManagedObject
            }

            var objectIDError: ErrorType? = nil
            if managedObject == nil {
                let object = NSManagedObject(entity: entity, insertIntoManagedObjectContext: context)
                do {
                    try context.obtainPermanentIDsForObjects([object])
                } catch { objectIDError = error  }

                if objectIDError != nil { throw objectIDError! }

                managedObject = object
            }

            return managedObject!
            
        } catch {
            throw error
        }
    }
    
}