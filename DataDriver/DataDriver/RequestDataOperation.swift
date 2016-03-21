//
//  RequestDataOperation.swift
//  DataDriver
//
//  Created by ERIKHEATH A THOMAS on 3/15/16.
//  Copyright © 2016 Curated Cocoa LLC. All rights reserved.
//

import Foundation
import CoreData
/*
TODO: Consider converting this to a URLSessionTransaction operation.

*/
class RequestDataOperation: Operation {

    var requestConstructed: Bool = false

    override func execute() {
        do {
                let resolvedRequest = try request.resolveURL()
                let dataTask = self.URLSession.dataTaskWithRequest(resolvedRequest)
                dataTask.resume()
            }
        } catch {
            let userInfoDict:[String: AnyObject] = [kUnderlyingErrorsArrayKey: [error as NSError]]
            NSNotificationCenter.defaultCenter().postNotificationName(kErrorNotification, object: nil, userInfo:userInfoDict)
        }

    }

    
}