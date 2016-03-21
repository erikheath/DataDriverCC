//
//  Constants.swift
//

import Foundation


// MARK: Error Related
let kErrorDomain = "kErrorDomain"
let kUnderlyingErrorsArrayKey = "kUnderlyingErrorsArrayKey"
let kParameter = "kParameter"
let kClassType = "kClassType"
let kMethodName = "kMethodName"
let kErrorNotification = "kErrorNotification"
let kDataRetrievalErrorNotification = "kDataRetrievalErrorNotification"
let kDataRequestErrorNotification = "kDataRetrievalErrorNotification"
let kDataTransformationErrorNotification = "kDataTransformationErrorNotification"
let kUserInfoErrorKey = "kUserInfoErrorKey"
let kThrownExceptionKey = "kThrownExceptionKey"
let kErrorCode = 112358

public enum DataLayerError: Int, ErrorType {
    case missingParameterError = 5000
    case genericError = 5001
    case parameterTypeError = 5002

    var objectType : NSError {
        get {
            return NSError(domain: kErrorDomain, code: self.rawValue, userInfo: nil)
        }
    }
}



// MARK: Remote Store Model User Info Keys
let kAPIVersion = "remotestore.apiversion"
let kBaseURL = "remotestore.baseurl"
let kEntityID = "remotestore.entityid"
let kJSONKeyPath = "remotestore.jsonkeypath"
let kJSONRootKeyPath = "remotestore.jsonrootkeypath"
let kSearchPathFormat = "remotestore.searchpathformat"
let kBaseURLPort = "remotestore.port"
let kSearchPathFormatTokens = "remotestore.searchpathformattokens"
let kScheme = "remotestore.scheme"
let kFallthough = "remotestore.fallthrough"
let kCachePolicyEnabled = "remotestore.enablecachepolicy"
let kCoordinatorShouldUseDefaultRemoteStoreHost = "remotestore.usedefaultstorehost"
let kRerootJSONSource = "remotestore.rerootjsonsource"
let kDownloadResourceOption = "remotestore.resourceRequestOption"
let kDownloadResourceOnSet = "downloadOnSet"
let kDownloadResourceOnGet = "downloadOnGet"
let kDownloadResourceOnCreate = "downloadOnCreate"
let kDownloadResourceOnFetch = "downloadOnFetch"
let kDownloadResourceTargetEntity = "localstore.targetentity"
let kDownloadResourceTargetProperty = "localstore.targetproperty"
let kRemoteStorePathFormat = "remotestore.pathformat"
let kRemoteStoreFetchLimitValue = "remotestore.queryitem.resultslimit.value"
let kRemoteStoreFetchLimitKey = "remotestore.queryitem.resultslimit.key"
let kRemoteStoreClientIDValue = "remotestore.queryitem.clientid.value"
let kRemoteStoreClientIDKey = "remotestore.queryitem.clientid.key"
let kRemoteStoreRequestSchemaKey = "remotestore.queryitem.requestschema.key"
let kRemoteStoreRequestSchemaValue = "remotestore.queryitem.requestschema.value"
let kRemoteStoreURLResponse = "remotestore.URLResponse"
let kPredicateParameters = "remotestore.predicateparameters"
let kRemoteStoreURLType = "remotestore.urltype"
let kRemoteStoreURLTypeFeed = "FEED"
let kRemoteStoreURLTypeImage = "IMAGE"
let kImageStoreType = "localstore.imagestoretype"
let kRemoteStoreResourceType = "remotestore.resourcetype"
let kRemoteStoreResourceTypeURL = "URL"

// MARK: Model Entity Keys
let kModelInfoEntity = "ModelSettings"
let kCoordinatorShouldReturnAvailableResults =  "localstore.returnavailableresults"
let kStoreInImageCache = "localstore.storeinimagecache"
let kImageCacheRoot = "localstore.imagecacheroot"
let kModelEntityID = "localstore.entityid"
let kPersistToLocalCache = "localstore.persisttolocalcache"
let kFlushLocalObjectsOnRemoteUpdate = "localstore.flushlocalobjectsonremoteupdate"
let kContextSaveBatchSize = "localstore.contextsavebatchsize"
let kRemoteStoreAttributeQueryKey = "remotestore.attribute.query.key"
let kStoreCoordinateQueryLatitudeKeypath = "coordinate.latitude.query.key"
let kStoreCoordinateQueryLongitudeKeypath = "coordinate.longitude.query.key"
let kFormatTokens = "formattokens"
let kHeaderParameters = "remotestore.headerparameters"
let kQueryParameters = "remotestore.queryparameters"
let kTimeToLive = "localstore.timetolive"
let kOverrideComponents = "localstore.overridecomponents"
let kOverrideTokens = "localstore.overridetokens"
let kExpirationInterval = "localstore.expirationInterval"
let kLastRemoteUpdate = "lastRemoteUpdate"
let kRemoteUpdateExpiration = "remoteUpdateExpiration"
let kRemoteUpdateInterval = "remoteUpdateInterval"
let kRemoteOrderPosition = "remoteOrderPosition"

// MARK: Local Store Notification Keys
public let kObjectIDsForRequestNotification = "kObjectIDsForRequestNotification"
public let kObjectIDsArray = "kObjectIDsArray"
public let kImageUpdatedNotification = "kImageUpdatedNotification"

// MARK: NSURLRequest Category
public let kRequestResponseKey = "kRequestResponseKey"


