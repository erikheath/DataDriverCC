//
//  URLProcessor.swift
//

import Foundation
import CoreData

protocol URLProcessor {

    func process(changeRequest: RemoteStoreRequest) -> Array<RemoteStoreRequest>
}

public class URLProcessorFactory {

    private static var processors:Dictionary<String, Dictionary<String, URLProcessor>> = Dictionary<String, Dictionary<String, URLProcessor>>()

    static func registerProcessor(processorName: String, processor: URLProcessor, stackID: String) {
        processors.updateValue([processorName: processor], forKey: stackID)
    }

    static func unregisterProcessor(processorName: String, stackID: String) {
        processors[stackID]?.removeValueForKey(processorName)
    }

    static func processor(processorName: String, stackID: String) -> URLProcessor? {
        return processors[stackID]?[processorName]
    }

}


