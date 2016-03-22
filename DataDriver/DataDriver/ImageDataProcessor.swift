//
//  ImageDataProcessor.swift
//


import CoreData

public class ImageDataProcessor: NSObject {

    // MARK: Error Management

    /**
     Errors produced during image processing.
    */
    public enum ImageProcessingError: Int, ErrorType {
        case formatError = 6200
        case expectedAttributeValueError = 6201
        case expectedAttributeError = 6202
        case expectedAttributeTypeError = 6203
        case missingUserInfoDictionary = 6205
        case missingAttributeError = 6206
        case missingPropertyValues = 6207
        case missingObjectIDError = 6210
        case unknownObjectError = 6211
    }

    /**
     Storage destination options when processing image data. Options include:
     
     - URLCache: Performs no disk or db related storage, defaulting to the sytem provided URL downloads cache.
     - DiskCache: Writes to an on-disk cache.
     - LocalStore: Write to an attribute designated for binary data storage.

     */
    public enum ImageStoreType: String, CustomStringConvertible {
        case URLCache = "URLCache"
        case DiskCache = "DiskCache"
        case LocalStore = "LocalStore"

        public var description:String { return self.rawValue }

    }

    /**
     Returns the image cache URL corresponding to an on-disk directory, creating one if it does not exist.
     */
    public let cacheURL: NSURL? = {
        do {
            var destinationURL = try NSFileManager.defaultManager().URLForDirectory(.CachesDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent(kImageCacheRoot)
            var writeError: NSError? = nil
            NSFileCoordinator().coordinateWritingItemAtURL(destinationURL, options: .ForReplacing, error: &writeError, byAccessor: { (newURL) -> Void in
                do {
                    try NSFileManager.defaultManager().createDirectoryAtURL(newURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    writeError = error as NSError
                }
            })

            if writeError != nil { throw writeError! }

            return destinationURL

        } catch {
            return nil
        }
    }()

    /**
     Processes the image data received from a URL response by looking at the target property description for image related keys. Possible keys include:

     - URLCache
     - DiskCache
     - LocalStore

     See the ImageStoreType enumeration for additional information on store types.

     - Parameter imageData: The data received as the response to a URL Request.
     
     - Parameter request: The original request that triggered the response.

     - Parameter parentContext: The context that should be used for posting changes to the local store.

     - Returns: An array of managed object ids that were changed as a result of the image processing; this is typically one object.
     
     - Throws: In the event of an error, typically an Image Processing Error, File Manager Error, File Coordinator Error, etc., depending on the stage of processing.

     */
    func processImageData(imageData: NSData, request: NSURLRequest, context: NSManagedObjectContext) throws -> Array<NSManagedObjectID> {

        guard let requestProperty = request.requestProperty, let userInfo = requestProperty.userInfo, let storeType = userInfo[kImageStoreType] as? String else {
            throw ImageProcessingError.missingPropertyValues
        }

        switch storeType {

        case ImageStoreType.URLCache.description:
            return []

        case ImageStoreType.DiskCache.description:
            try self.processDiskCacheImageData(imageData, request: request)
            return []

        case ImageStoreType.LocalStore.description:
            return [ try self.processLocalStoreImageData(imageData, request: request, context: context) ]

        default:
            return []

        }

    }

    /**
     Processes the image data for writing to the local disk cache.
     
     - Parameter imageData: The data to write to the local cache.
     
     - Parameter request: The URL request that resulted in the image data.
     
     - Throws: In the event of an error, typically an Image Processing Error, File Manager Error, File Coordinator Error, etc., depending on the stage of processing.

     */
    func processDiskCacheImageData( imageData: NSData, request: NSURLRequest) throws {
        guard let requestURL = request.URL, let pathExtension = requestURL.pathExtension else { throw ImageProcessingError.formatError }
        let destinationFileName = String(requestURL.absoluteString.hash) + "." + pathExtension
        guard let destinationFileURL = self.cacheURL?.URLByAppendingPathComponent( destinationFileName, isDirectory: false) else { throw ImageProcessingError.formatError }
        var writeError: NSError? = nil
        NSFileCoordinator().coordinateWritingItemAtURL(destinationFileURL, options: .ForReplacing, error: &writeError, byAccessor: { (newURL) -> Void in
            do {
                try imageData.writeToURL(newURL, options: .DataWritingAtomic)
            } catch {
                writeError = error as NSError
            }
        })

        if writeError != nil {
            throw writeError!
        }
    }

    /**
     Processes the image data for writing to the local store. Depending on setup, this may result in writing to disk.

     - Parameter imageData: The data to write to the local cache.

     - Parameter request: The URL request that resulted in the image data.
     
     - Parameter context: The context the destination object should be retrieved from.
     
     - Returns: The ID of the object changed as a result of writing the binary image data.
     
     - Throws: In the event of an error, typically an Image Processing Error, File Manager Error, File Coordinator Error, etc., depending on the stage of processing.
     */
    func processLocalStoreImageData( imageData: NSData, request: NSURLRequest, context: NSManagedObjectContext) throws -> NSManagedObjectID {
        guard let requestProperty = request.requestProperty else { throw ImageProcessingError.missingPropertyValues }
        guard let destinationID = request.destinationObjectID else { throw ImageProcessingError.missingObjectIDError }
        let destinationObject = context.objectWithID(destinationID)
        let destinationKey = requestProperty.name
        guard destinationObject.entity.attributesByName[destinationKey] != nil else { throw ImageProcessingError.missingAttributeError }

        destinationObject.setValue(imageData, forKey: destinationKey)

        return destinationID

    }



}