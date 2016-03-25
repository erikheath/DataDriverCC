//
//  URLResponse.swift
//

import Foundation
import CoreData

protocol URLResponse {
    func process(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL, backgroundContext: NSManagedObjectContext) -> NSOperation
}

public class URLResponseFactory {

    private static var processors:Dictionary<String, Dictionary<String, URLResponse>> = Dictionary<String, Dictionary<String, URLResponse>>()

    static func registerProcessor(entityName: String, entityProcessor: URLResponse, stackID: String) {
        processors.updateValue([entityName: entityProcessor], forKey: stackID)
    }

    static func unregisterProcessor(entityName: String) {
        processors.removeValueForKey(entityName)
    }

    static func processor(entityName: String, stackID: String) -> URLResponse? {
        return processors[stackID]?[entityName]
    }

}
