//
//  JSONAttributeProcessor.swift
//


import CoreData

public class JSONAttributeProcessor: NSObject {

    private var transaction: TransactionOperation

    private var stackID: String

    init(transaction: TransactionOperation, stackID: String) {
        self.stackID = stackID
        self.transaction = transaction
    }
    
    /**
     This method fulfills an objects attribute (property) values. If the incoming value is null or the empty string, this means the attribute will be set to nil in the local store. If the key returns nil, this means the key is not in the dictionary and the local property will not be set.
     
     - Parameter managedObject: The managed object whose attributes should be fulfilled.
     
     - Parameter valueSource: The value source that should be used to fulfill the attributes of the managed object.
     
     - Throws: Various JSONParseError and NSManagedObjectContext errors.
     
     */
    func fulfillManagedObject(managedObject:NSManagedObject, valueSource: NSDictionary) throws -> Void {

        guard let attributesDictionary:Dictionary<String, NSAttributeDescription> = managedObject.entity.attributesByName as Dictionary<String, NSAttributeDescription> else {
            throw JSONCollectionProcessor.JSONParserError.missingAttributes
        }

        for (attributeKey, attribute) in attributesDictionary {

            var attributeValue:AnyObject?

            if let key = attribute.userInfo?[kJSONKeyPath] as? String {

                if let valueToCheck:NSObject = valueSource.valueForKeyPath(key) as? NSObject {

                    switch attribute.attributeType {

                    case .Integer16AttributeType, .Integer32AttributeType, .Integer64AttributeType:
                        try attributeValue = self.processIntegerAttribute(valueToCheck)

                    case .DecimalAttributeType:
                        try attributeValue = self.processDecimalAttribute(valueToCheck)

                    case .DoubleAttributeType:
                        try attributeValue = self.processDoubleAttribute(valueToCheck)

                    case .FloatAttributeType:
                        try attributeValue = self.processFloatAttribute(valueToCheck)

                    case .StringAttributeType:
                        try attributeValue = self.processStringAttribute(valueToCheck)

                    case .BooleanAttributeType:
                        try attributeValue = self.processBooleanAttribute(valueToCheck)

                    case .DateAttributeType:
                        try attributeValue = self.processDateAttribute(valueToCheck)

                    case .TransformableAttributeType:
                        try attributeValue = self.processTransformableAttribute(valueToCheck, attributeDescription: attribute, managedObject: managedObject)

                    case .ObjectIDAttributeType, .BinaryDataAttributeType, .UndefinedAttributeType:
                        break

                    }

                    managedObject.setValue(attributeValue, forKey: attributeKey)

                }
            }
        }
    }


    func processIntegerAttribute(attribute: NSObject) throws -> AnyObject? {
        var attributeValue:AnyObject?

        switch attribute {

        case is String:
            attributeValue = NSNumber(integer: (attribute as! NSString).integerValue)
        case is NSNull:
            attributeValue = nil
        case is NSNumber:
            attributeValue = attribute
        default:
            throw JSONCollectionProcessor.JSONParserError.expectedAttributeTypeError
        }

        return attributeValue
    }

    func processDecimalAttribute(attribute: NSObject) throws -> AnyObject? {
        var attributeValue:AnyObject?

        switch attribute {

        case is String:
            attributeValue = NSDecimalNumber(string: attribute as? String)
        case is NSNumber:
            attributeValue = NSDecimalNumber(decimal: (attribute as! NSNumber).decimalValue)
        case is NSNull:
            attributeValue = nil
        default:
            throw JSONCollectionProcessor.JSONParserError.expectedAttributeTypeError
        }

        return attributeValue
    }

    func processDoubleAttribute(attribute: NSObject) throws -> AnyObject? {
        var attributeValue:AnyObject?

        switch attribute {

        case is String:
            attributeValue = NSNumber(double: ((attribute as! NSString).doubleValue)) //autotest: attribute: String == NSNumber.DoubleType(1.0..8.5)
        case is NSNull:
            attributeValue = nil //autotest: NSNull == nil
        case is NSNumber:
            attributeValue = attribute //autotest: attribute as NSNumber == attributeValue
        default:
            throw JSONCollectionProcessor.JSONParserError.expectedAttributeTypeError //autotest: attribute: RandomType throws 
        }

        return attributeValue
    }

    func processFloatAttribute(attribute: NSObject) throws -> AnyObject? {
        var attributeValue:AnyObject?

        switch attribute {

        case is String:
            attributeValue = NSNumber(float: ((attribute as! NSString).floatValue))
        case is NSNull:
            attributeValue = nil
        case is NSNumber:
            attributeValue = attribute
        default:
            throw JSONCollectionProcessor.JSONParserError.expectedAttributeTypeError
        }

        return attributeValue
    }

    func processStringAttribute(attribute: NSObject) throws -> AnyObject? {
        var attributeValue:AnyObject?

        switch attribute {

        case is NSNumber:
            attributeValue = attribute.description
        case is NSNull:
            attributeValue = nil
        case is String:
            attributeValue = attribute
        default:
            throw JSONCollectionProcessor.JSONParserError.expectedAttributeTypeError
        }

        return attributeValue
    }

    func processBooleanAttribute(attribute: NSObject) throws -> AnyObject? {
        var attributeValue:AnyObject?

        switch attribute {

        case is String:
            attributeValue = NSNumber(bool: (attribute as! NSString).boolValue)
        case is NSNull:
            attributeValue = nil
        case is NSNumber:
            attributeValue = attribute
        default:
            throw JSONCollectionProcessor.JSONParserError.expectedAttributeTypeError
        }

        return attributeValue
    }

    func processDateAttribute(attribute: NSObject) throws -> AnyObject? {
        var attributeValue:AnyObject?

        switch attribute {

        case is String:
            let enUSPOSIXLocale = NSLocale(localeIdentifier: "en_US_POSIX")
            let dateFormatter = NSDateFormatter()
            dateFormatter.locale = enUSPOSIXLocale
            dateFormatter.dateFormat = "yyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
            dateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
            if let convertedAttribute = dateFormatter.dateFromString(attribute as! String) {
                attributeValue = convertedAttribute
            } else {
                throw JSONCollectionProcessor.JSONParserError.expectedAttributeTypeError
            }
        case is NSNull:
            attributeValue = nil
        default:
            throw JSONCollectionProcessor.JSONParserError.expectedAttributeTypeError
        }

        return attributeValue
    }

    func processTransformableAttribute(attribute: NSObject, attributeDescription: NSAttributeDescription, managedObject: NSManagedObject) throws -> AnyObject? {
        var attributeValue:AnyObject?

        switch attribute {

        case is String:
            if let convertedAttribute = NSURL(string: attribute as! String) where attributeDescription.userInfo?[kRemoteStoreResourceType] as? String == kRemoteStoreResourceTypeURL {
                attributeValue = convertedAttribute
                // If the item should be downloaded, spawn an operation using a change request generated by a custom processor. A processor must be registered for the entity by the app.
                guard let targetEntityName = attributeDescription.userInfo?[kDownloadResourceTargetEntity] as? String where attributeDescription.userInfo?[kDownloadResourceOption] as? String == kDownloadResourceOnCreate else { break }
                guard let context = managedObject.managedObjectContext, let targetEntity = NSEntityDescription.entityForName(targetEntityName, inManagedObjectContext: context) else { break }
                var targetProperty: NSPropertyDescription? = nil
                if let targetPropertyName = attributeDescription.userInfo?[kDownloadResourceTargetProperty] as? String {
                    targetProperty = targetEntity.propertiesByName[targetPropertyName]
                }
                var targetObjectID: NSManagedObjectID? = nil
                if targetProperty != nil { targetObjectID = managedObject.objectID }
                let URLOverrides = NSURLComponents(URL: convertedAttribute, resolvingAgainstBaseURL: false)
                let changeRequest = RemoteStoreRequest(entity: targetEntity, property: targetProperty, predicate: nil, URLOverrides: URLOverrides, overrideTokens: nil, methodType: RemoteStoreRequest.RequestType.GET, methodBody: nil, destinationID: targetObjectID)
                if let processor = URLProcessorFactory.processor(targetEntityName, stackID: self.stackID) {
                    let changeRequestArray = processor.process(changeRequest) // This is where customization can occur
                    if changeRequestArray.count > 0 {
                        for changeRequest in changeRequestArray {
                            self.transaction.addRemoteStoreRequest(changeRequest)
                        }
                    }
                } else {
                    self.transaction.addRemoteStoreRequest(changeRequest)
                }
                
            }
        case is NSNull:
            attributeValue = nil
        default:
            throw JSONCollectionProcessor.JSONParserError.expectedAttributeTypeError
        }
        
        return attributeValue
    }

    /**
            // If the key is in the response but has no data, this effectively sets the property to nil / null. Numbers without values are converted to the default (0) by NSString. If a property is null, it will be set to nil.

*/
}
