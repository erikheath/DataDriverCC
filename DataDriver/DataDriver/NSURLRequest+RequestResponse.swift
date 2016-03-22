//
//  NSURLRequest+RequestResponse.swift
//

import Foundation
import CoreData

public enum FulfillmentStatus: Int {
    case unknown = 0
    case pending = 1
    case fulfilled = 2
    case error = 3
}

extension NSURLRequest {

    // MARK: Extended Properties
    internal enum ExtendedKeys: String {
        case requestEntityKey = "com.localStore.requestEntityKey"
        case overrideComponentsKey = "com.remoteStore.overrideKey"
        case remoteResponseKey = "com.remoteStore.responseKey"
        case requestPredicateKey = "com.localStore.requestPredicateKey"
        case requestPropertyKey = "com.localStore.requestAttributeKey"
        case overrideTokensKey = "com.localStore.overrideTokensKey"
        case replacementTokensKey = "com.localStore.replacementTokensKey"
        case dataFulfillmentKey = "com.localStore.datafulfillmentKey"
        case responseProcessingOperation = "com.localStore.responseProcessingOperation"
        case destinationObjectKey = "com.localStore.destinationObjectKey"
        
    }

    // The target attributes that generated the Request. May be nil.
    public var requestProperty:NSPropertyDescription? {

        get {
            return NSURLProtocol.propertyForKey(ExtendedKeys.requestPropertyKey.rawValue, inRequest: self) as? NSPropertyDescription
        }
    }

    // The fetch request that generated the Request. May be nil.
    public var requestEntity: NSEntityDescription? {
        get {
            return NSURLProtocol.propertyForKey(ExtendedKeys.requestEntityKey.rawValue, inRequest: self) as? NSEntityDescription
        }
    }

    // The destination object id. May be nil.
    public var destinationObjectID: NSManagedObjectID? {
        get {
            return NSURLProtocol.propertyForKey(ExtendedKeys.destinationObjectKey.rawValue, inRequest: self) as? NSManagedObjectID
        }
    }

    // The request predicate the generated the Request. May be nil.
    public var requestPredicate: NSPredicate? {
        get {
            return NSURLProtocol.propertyForKey(ExtendedKeys.requestPredicateKey.rawValue, inRequest: self) as? NSPredicate
        }
    }

    // The response operation that should be used to process the request. May be nil.
    public var responseOperation: NSString? {
        get {
            return NSURLProtocol.propertyForKey(ExtendedKeys.responseProcessingOperation.rawValue, inRequest: self) as? NSString
        }
    }


    // A set of components that will override components of the resolved remote store URL. May be nil.
    public var URLOverrideComponents: NSURLComponents? {
        get {
            return NSURLProtocol.propertyForKey(ExtendedKeys.overrideComponentsKey.rawValue, inRequest: self) as? NSURLComponents
        }
    }

    // The data fulfillment status of the request.
    public var dataFulfillment: FulfillmentStatus {
        get {
            guard let fulfilled = NSURLProtocol.propertyForKey(ExtendedKeys.dataFulfillmentKey.rawValue, inRequest: self) as? NSNumber,
            let status = FulfillmentStatus.init(rawValue: fulfilled as Int) else {
                return FulfillmentStatus.unknown
            }
            return status
        }
    }

    // The response received from the server. May be nil.
    public var remoteResponse:NSHTTPURLResponse? {
        get {
            return NSURLProtocol.propertyForKey(ExtendedKeys.remoteResponseKey.rawValue, inRequest: self) as? NSHTTPURLResponse
        }
    }

    // The tokens and values used to replace those tokens.
    public var overrideTokens: Dictionary<NSObject, AnyObject>? {
        return NSURLProtocol.propertyForKey(ExtendedKeys.overrideTokensKey.rawValue, inRequest: self) as? Dictionary<NSObject, AnyObject>
    }

    // The computed replacementTokens from all available sources.
    public var replacementTokens: Dictionary<NSObject, AnyObject> {
        if let replacementTokens = NSURLProtocol.propertyForKey(ExtendedKeys.replacementTokensKey.rawValue, inRequest: self) as? Dictionary<NSObject, AnyObject> {
            return replacementTokens
        } else {
            let methodType = self.HTTPMethod!.lowercaseString

            let mergedReplacements = NSMutableDictionary()

            // The master settings from the model for the request
            model: do {

                guard let formatTokens = (self.requestEntity?.managedObjectModel.entitiesByName[kModelInfoEntity]?.userInfo?[kFormatTokens + "." + methodType] as? NSString)?.propertyList() as? Dictionary<NSObject, AnyObject> else {
                    break model
                }

                mergedReplacements.addEntriesFromDictionary(formatTokens)
            }


            // The entity which generated the request
            entity: do {

                guard let formatTokens = (self.requestEntity?.userInfo?[kFormatTokens + "." + methodType] as? NSString)?.propertyList() as? Dictionary<NSObject, AnyObject> else {
                    break entity
                }

                mergedReplacements.addEntriesFromDictionary(formatTokens)

            }

            // The attributes which generated the request
            attributes: do {

                guard let formatTokens = (self.requestProperty?.userInfo?[kFormatTokens + "." + methodType] as? NSString)?.propertyList() as? Dictionary<NSObject, AnyObject> else {
                    break attributes
                }

                mergedReplacements.addEntriesFromDictionary(formatTokens)
            }

            // The overrides that should be applied to the request
            overrides: do {

                guard let formatTokens = self.overrideTokens else {
                    break overrides
                }

                mergedReplacements.addEntriesFromDictionary(formatTokens)
            }
            return NSDictionary(dictionary: mergedReplacements) as! Dictionary<NSObject, AnyObject>
        }
    }

}

extension NSMutableURLRequest {


    // MARK: Object Lifecycle
    convenience init(entity:NSEntityDescription?, property:NSPropertyDescription?, predicate:NSPredicate?, URLOverrides:NSURLComponents?, overrideTokens:Dictionary<NSObject, AnyObject>?, destinationID: NSManagedObjectID?) {
        self.init()
        if let entity = entity {
            self.requestEntity = entity
        }
        if let propertyDescription = property {
            self.requestProperty = propertyDescription
        }
        if let predicate = predicate {
            self.requestPredicate = predicate
        }
        if let URLOverrides = URLOverrides {
            self.URLOverrideComponents = URLOverrides
        }
        if let overrideTokens = overrideTokens {
            self.overrideTokens = overrideTokens
        }
        if let destinationID = destinationID {
            self.destinationObjectID = destinationID
        }
    }


    // MARK: Extended Properties


    // The target attribute that generated the Request. May be nil. Only a request attribute or request Entity may be set, and setting the attribute will cause the entity to be the entity of the attribute.
    override public var requestProperty:NSPropertyDescription? {

        set(requestPropertyDescription) {
            if let requestPropertyDescription = requestPropertyDescription {
                NSURLProtocol.setProperty(requestPropertyDescription, forKey: ExtendedKeys.requestPropertyKey.rawValue, inRequest: self)
            } else {
                NSURLProtocol.removePropertyForKey(ExtendedKeys.requestPropertyKey.rawValue, inRequest: self)
            }
        }

        get {
            return NSURLProtocol.propertyForKey(ExtendedKeys.requestPropertyKey.rawValue, inRequest: self) as? NSPropertyDescription
        }
    }


    // The target entity that generated the Request. May be nil. Only a request attribute or request Entity may be set, and setting one will cause the other to be set to nil.
    override public var requestEntity: NSEntityDescription? {

        set(requestEntity) {
            if let requestEntity = requestEntity {
                NSURLProtocol.setProperty(requestEntity, forKey: ExtendedKeys.requestEntityKey.rawValue, inRequest: self)
            } else {
                NSURLProtocol.removePropertyForKey(ExtendedKeys.requestEntityKey.rawValue, inRequest: self)
            }
        }

        get {
            return NSURLProtocol.propertyForKey(ExtendedKeys.requestEntityKey.rawValue, inRequest: self) as? NSEntityDescription
        }

    }

    // The destination object for the request.
    override public var destinationObjectID: NSManagedObjectID? {

        set(destinationObjectID) {
            if let destinationObjectID = destinationObjectID {
                NSURLProtocol.setProperty(destinationObjectID, forKey: ExtendedKeys.destinationObjectKey.rawValue, inRequest: self)
            } else {
                NSURLProtocol.removePropertyForKey(ExtendedKeys.destinationObjectKey.rawValue, inRequest: self)
            }
        }

        get {
            return NSURLProtocol.propertyForKey(ExtendedKeys.destinationObjectKey.rawValue, inRequest: self) as? NSManagedObjectID
        }
    }


    // The predicate associated with the request. May be nil.
    override public var requestPredicate: NSPredicate? {

        set(requestPredicate) {
            if let requestPredicate = requestPredicate {
                NSURLProtocol.setProperty(requestPredicate, forKey: ExtendedKeys.requestPredicateKey.rawValue, inRequest: self)
            } else {
                NSURLProtocol.removePropertyForKey(ExtendedKeys.requestPredicateKey.rawValue, inRequest: self)
            }
        }

        get {
            return NSURLProtocol.propertyForKey(ExtendedKeys.requestPredicateKey.rawValue, inRequest: self) as? NSPredicate
        }
    }

    // The response operation that should be used to process the request. May be nil.
    override public var responseOperation: NSString? {

        set(responseOperation) {
            if let responseOperation = responseOperation {
                NSURLProtocol.setProperty(responseOperation, forKey: ExtendedKeys.responseProcessingOperation.rawValue, inRequest: self)
            } else {
                NSURLProtocol.removePropertyForKey(ExtendedKeys.responseProcessingOperation.rawValue, inRequest: self)
            }
        }

        get {
            return NSURLProtocol.propertyForKey(ExtendedKeys.responseProcessingOperation.rawValue, inRequest: self) as? NSString
        }
    }

    // A set of components that will override components of the resolved remote store URL. May be nil.
    override public var URLOverrideComponents: NSURLComponents? {

        set(URLOverrideComponents) {
            if let URLOverrideComponents = URLOverrideComponents {
                NSURLProtocol.setProperty(URLOverrideComponents, forKey: ExtendedKeys.overrideComponentsKey.rawValue, inRequest: self)
            } else {
                NSURLProtocol.removePropertyForKey(ExtendedKeys.overrideComponentsKey.rawValue, inRequest: self)
            }
        }

        get {
            return NSURLProtocol.propertyForKey(ExtendedKeys.overrideComponentsKey.rawValue, inRequest: self) as? NSURLComponents
        }
    }

    // The data fulfillment status of the request.
    public func dataFulfillment(status: FulfillmentStatus) -> Void {

        let status: NSNumber = dataFulfillment.rawValue
        NSURLProtocol.setProperty(status, forKey: ExtendedKeys.dataFulfillmentKey.rawValue, inRequest: self)
    }


    // The response received from the server. May be nil.
    override public var remoteResponse:NSHTTPURLResponse? {

        set(remoteResponse) {
            if let remoteResponse = remoteResponse {
                NSURLProtocol.setProperty(remoteResponse, forKey: ExtendedKeys.remoteResponseKey.rawValue, inRequest: self)
            } else {
                NSURLProtocol.removePropertyForKey(ExtendedKeys.remoteResponseKey.rawValue, inRequest: self)
            }
        }

        get {
            return NSURLProtocol.propertyForKey(ExtendedKeys.remoteResponseKey.rawValue, inRequest: self) as? NSHTTPURLResponse
        }
    }

    // The tokens and values used to replace those tokens.
    override public var overrideTokens: Dictionary<NSObject, AnyObject>? {

        set(overrideTokens) {
            if let overrideTokens = overrideTokens {
                NSURLProtocol.setProperty(overrideTokens, forKey: ExtendedKeys.overrideTokensKey.rawValue, inRequest: self)
            } else {
                NSURLProtocol.removePropertyForKey(ExtendedKeys.overrideTokensKey.rawValue, inRequest: self)
            }
        }

        get {
            return NSURLProtocol.propertyForKey(ExtendedKeys.overrideTokensKey.rawValue, inRequest: self) as? Dictionary<NSObject, AnyObject>
        }
    }

    // The computed replacementTokens from all available sources.
    override public var replacementTokens: Dictionary<NSObject, AnyObject> {
        get {
            if let replacementTokens = NSURLProtocol.propertyForKey(ExtendedKeys.replacementTokensKey.rawValue, inRequest: self) as? Dictionary<NSObject, AnyObject> {
                return replacementTokens
            } else {
                let methodType = self.HTTPMethod.lowercaseString
                let mergedReplacements = NSMutableDictionary()

                // The master settings from the model for the request
                model: do {

                    guard let formatTokens = (self.requestEntity?.managedObjectModel.entitiesByName[kModelInfoEntity]?.userInfo?[kFormatTokens + "." + methodType] as? NSString)?.propertyList() as? Dictionary<NSObject, AnyObject> else {
                        break model
                    }

                    mergedReplacements.addEntriesFromDictionary(formatTokens)
                }


                // The entity which generated the request
                entity: do {

                    guard let formatTokens = (self.requestEntity?.userInfo?[kFormatTokens + "." + methodType] as? NSString)?.propertyList() as? Dictionary<NSObject, AnyObject> else {
                        break entity
                    }

                    mergedReplacements.addEntriesFromDictionary(formatTokens)

                }

                // The attributes which generated the request
                attributes: do {

                    guard let formatTokens = (self.requestProperty?.userInfo?[kFormatTokens + "." + methodType] as? NSString)?.propertyList() as? Dictionary<NSObject, AnyObject> else {
                        break attributes
                    }

                    mergedReplacements.addEntriesFromDictionary(formatTokens)
                }

                // The overrides that should be applied to the request
                overrides: do {

                    guard let formatTokens = self.overrideTokens else {
                        break overrides
                    }

                    mergedReplacements.addEntriesFromDictionary(formatTokens)
                }

                NSURLProtocol.setProperty(mergedReplacements, forKey: ExtendedKeys.replacementTokensKey.rawValue, inRequest: self)

                return NSDictionary(dictionary: mergedReplacements) as! Dictionary<NSObject, AnyObject>
            }
        }
    }

    // MARK: Processing Methods

    func resolveComponents(URLComponents:NSURLComponents, userInfo:NSDictionary) -> Void {
        let methodType = self.HTTPMethod.lowercaseString

        if let scheme = userInfo[kScheme + "." + methodType] as? String where scheme != "" {
            URLComponents.scheme = scheme
        }
        if let host = userInfo[kBaseURL + "." + methodType] as? String where host != "" {
            URLComponents.host = host
        }
        if let path = userInfo[kSearchPathFormat + "." + methodType] as? String where path != "" {
            URLComponents.path = path
        }
        if let port = userInfo[kBaseURLPort + "." + methodType] as? String where port != "" {
            guard let portNumber = Int(port) else { return }
            URLComponents.port = portNumber
        }

    }

    func resolveOverrides(URLComponents:NSURLComponents, overrides:NSURLComponents) -> NSURLComponents {

        let components = overrides.copy() as! NSURLComponents

        if components.scheme == nil {
            components.scheme = URLComponents.scheme
        }

        if components.host == nil {
            components.host = URLComponents.host
        }

        if components.path == nil {
            components.path = URLComponents.path
        }

        if components.query == nil {
            components.query = URLComponents.query
        }

        if components.port == nil {
            components.port = URLComponents.port
        }

        return components
    }

    // Resolves the request URL using settings from the request model, the request entity, the request attribute, and the request overrides.
    func resolveURL() throws -> NSMutableURLRequest {

        var URLComponents = NSURLComponents()
        let headerParameters:NSMutableDictionary = NSMutableDictionary()
        let mergedUserInfo:NSMutableDictionary = NSMutableDictionary()
        let queryParameters:NSMutableArray = NSMutableArray()

        // The master settings from the model for the request
        model: do {

            guard let userInfo = self.requestEntity?.managedObjectModel.entitiesByName[kModelInfoEntity]?.userInfo else {
                break model
            }
            self.resolveComponents(URLComponents, userInfo: userInfo)
            if let headers = self.resolveHeaderParameters(userInfo) {
                headerParameters.addEntriesFromDictionary(headers)
            }
            if let queries = self.resolveQueryParameters(userInfo) {
                self.addQueryItems(queryParameters, fromArray: queries)
            }
            mergedUserInfo.addEntriesFromDictionary(userInfo)

        }


        // The entity which generated the request
        entity: do {

            guard let userInfo = self.requestEntity?.userInfo else {
                break entity
            }
            self.resolveComponents(URLComponents, userInfo: userInfo)
            if let headers = self.resolveHeaderParameters(userInfo) {
                headerParameters.addEntriesFromDictionary(headers)
            }
            if let queries = self.resolveQueryParameters(userInfo) {
                self.addQueryItems(queryParameters, fromArray: queries)
            }
            mergedUserInfo.addEntriesFromDictionary(userInfo)

        }

        // The attributes which generated the request
        attributes: do {

            guard let userInfo = self.requestProperty?.userInfo else {
                break attributes
            }
            self.resolveComponents(URLComponents, userInfo: userInfo)
            if let headers = self.resolveHeaderParameters(userInfo) {
                headerParameters.addEntriesFromDictionary(headers)
            }
            if let queries = self.resolveQueryParameters(userInfo) {
                self.addQueryItems(queryParameters, fromArray: queries)
            }
            mergedUserInfo.addEntriesFromDictionary(userInfo)

        }

        // Query items for any predicate items.
        predicates: do {
            guard let predicate = self.requestPredicate else { break predicates }
            guard let queries = self.resolvePredicateAsQueryItems(predicate, userInfo: mergedUserInfo as NSDictionary as! Dictionary<NSObject, AnyObject>) where self.requestPredicate != nil else {
                break predicates
            }
            self.addQueryItems(queryParameters, fromArray: queries)
        }

        // The overrides that should be applied to the request
        overrides: do {

            guard let components = self.URLOverrideComponents else {
                break overrides
            }
            URLComponents = self.resolveOverrides(URLComponents, overrides: components)
            if let queries = URLComponents.queryItems {
                self.addQueryItems(queryParameters, fromArray: queries)
            }
        }

        // Retrieve the search path and replace all of the tokens within the search path component
        searchTokens: do {
            let tokens = self.replacementTokens as! Dictionary<NSString, String>
            guard var pathFormat = URLComponents.path as NSString? else {
                break searchTokens
            }
            for (token, value) in tokens {
                let normalizedToken = token.uppercaseString
                let searchRange = NSMakeRange(0, pathFormat.length)
                pathFormat = pathFormat.stringByReplacingOccurrencesOfString(normalizedToken as String, withString: value, options: NSStringCompareOptions(rawValue: 0), range:searchRange)
            }
            URLComponents.path = pathFormat as String
        }

        // Replace all of the tokens within the query component
        queryPath: do {
            URLComponents.queryItems = (queryParameters as NSArray) as? [NSURLQueryItem]
            let tokens = self.replacementTokens as! Dictionary<NSString, String>
            guard var queryPath = URLComponents.query as NSString? else {
                break queryPath
            }
            for (token, value) in tokens {
                let normalizedToken = token.uppercaseString
                let searchRange = NSMakeRange(0, queryPath.length)
                queryPath = queryPath.stringByReplacingOccurrencesOfString(normalizedToken as String, withString: value, options: NSStringCompareOptions(rawValue: 0), range:searchRange)
            }
        }


        // Replace all of the tokens within the parameter array.
        parameters: do {
            let tokens = self.replacementTokens as! Dictionary<NSString, String>
            for (token, value) in tokens {
                let normalizedToken = token.uppercaseString
                let headers = NSDictionary(dictionary: headerParameters)
                for (header, headerValue) in headers {
                    let searchRange = NSMakeRange(0, headerValue.length)
                    headerParameters[header as! NSString] = headerValue.stringByReplacingOccurrencesOfString(normalizedToken as String, withString: value, options: NSStringCompareOptions(rawValue: 0), range:searchRange)
                }
            }
        }

        // The URL that should be constructed
        do {

            guard let constructedURL: NSURL = URLComponents.URL else {
                throw DataLayerError.genericError
            }
            self.URL = constructedURL

        } catch {
            let description = String("Could not construct remote URL.")
            let failureReason = String("An error occurred during resolution of the URL components.")
            let recoveryOption = String("Confirm that the user info dictionary for model, entity, and/or attribute are set.")
            let userInfoDict:[String : AnyObject] = [NSLocalizedDescriptionKey: description, NSLocalizedFailureReasonErrorKey: failureReason, NSLocalizedRecoveryOptionsErrorKey: recoveryOption, kUnderlyingErrorsArrayKey:[error as NSError]]
            let wrappedError = NSError(domain: kErrorDomain, code: kErrorCode, userInfo: userInfoDict)
            throw wrappedError

        }

        return self

    }

    private func resolveHeaderParameters(userInfo:Dictionary<NSObject, AnyObject>) -> Dictionary<NSObject, AnyObject>? {
        let methodType = self.HTTPMethod.lowercaseString
        guard let headers = (userInfo[kHeaderParameters + "." + methodType] as? NSString)?.propertyList() as! NSDictionary? else {
            return Dictionary<NSObject, AnyObject>()
        }
        return headers as? Dictionary<NSObject, AnyObject>
    }

    private func resolveQueryParameters(userInfo:Dictionary<NSObject, AnyObject>) -> Array<AnyObject>? {
        let methodType = self.HTTPMethod.lowercaseString
        do {
            guard let queryDictionary = (userInfo[kQueryParameters + "." + methodType] as? NSString)?.propertyList() as! NSDictionary? else {
                return NSArray() as Array<AnyObject>
            }
            let queryArray = NSMutableArray()
            for (key, value) in queryDictionary {
                queryArray.addObject(NSURLQueryItem(name: key as! String, value: value as? String))
            }
            return queryArray as Array<AnyObject>
        }
    }

    private func addQueryItems(toArray: NSMutableArray, fromArray:Array<AnyObject>) -> Void {
        for queryItem in fromArray {
            let index = (toArray as NSArray).indexOfObjectWithOptions(NSEnumerationOptions.Concurrent, passingTest: { (query, idx, stop) -> Bool in
                if (query as! NSURLQueryItem).name == queryItem.name {
                    stop.memory = true
                    return true
                }
                return false
            })
            if index == NSNotFound {
                toArray.addObject(queryItem)
            } else {
                toArray.replaceObjectAtIndex(index, withObject: queryItem)
            }
        }
    }

    private func resolvePredicateAsQueryItems(predicate:NSPredicate, userInfo:Dictionary<NSObject, AnyObject>) -> Array<NSURLQueryItem>? {

        let methodType = self.HTTPMethod.lowercaseString

        var predicateItems: Array<NSComparisonPredicate> = []
        var queryItems: Array<NSURLQueryItem> = []

        do {
            switch predicate {

            case is NSComparisonPredicate:
                predicateItems.append(predicate as! NSComparisonPredicate)

            case is NSCompoundPredicate where (predicate as! NSCompoundPredicate).compoundPredicateType == NSCompoundPredicateType.AndPredicateType:
                predicateItems = (predicate as! NSCompoundPredicate).subpredicates as! Array<NSComparisonPredicate>

            default:
                break
            }

            do {
                guard let predicateDictionary = (userInfo[kPredicateParameters + "." + methodType] as? NSString)?.propertyList() as! Dictionary<String, Dictionary<String, AnyObject>>? else {
                    return []
                }

                predicateLoop: for (_, value) in predicateDictionary {
                    guard let parameterKey = value["parameterName"] as? String else {
                        continue predicateLoop
                    }
                    var parameterValue:String? = nil

                    parameterFormatLoop: do {
                        guard var parameterFormat = value["parameterFormat"] as? String else {
                            continue predicateLoop
                        }

                        var tokenArray:[String] = []

                        guard let parameterTokens = value["parameterTokens"] as? Array<String> else {
                            continue predicateLoop
                        }

                        tokenParameters: for token in parameterTokens {
                            for predicate in predicateItems {
                                if token == predicate.leftExpression.description {
                                    tokenArray.append(predicate.rightExpression.constantValue as! String)
                                    continue tokenParameters
                                }
                            }
                            break tokenParameters
                        }
                        
                        if parameterTokens.count != tokenArray.count {
                            continue predicateLoop
                        }
                        
                        for token in tokenArray {
                            let targetRange = (parameterFormat as NSString).rangeOfString("%@")
                            parameterFormat = (parameterFormat as NSString).stringByReplacingOccurrencesOfString("%@", withString: token, options: NSStringCompareOptions(rawValue: 0), range: targetRange)
                        }
                        
                        parameterValue = parameterFormat
                    }
                    
                    let item:NSURLQueryItem = NSURLQueryItem(name: parameterKey, value: parameterValue)
                    queryItems.append(item)
                }
            }
            
        }
        
        return queryItems
        
    }
    
}

