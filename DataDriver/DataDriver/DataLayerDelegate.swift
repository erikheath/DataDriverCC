//
//  DataLayerDelegate
//  DataDriver
//
//  Created by ERIKHEATH A THOMAS on 3/22/16.
//  Copyright © 2016 Curated Cocoa LLC. All rights reserved.
//

import Foundation

@objc public protocol DataLayerDelegate: NSObjectProtocol {

    optional func URLConfiguration(dataLayer: DataLayer, defaultURLConfiguration: NSURLSessionConfiguration) -> NSURLSessionConfiguration

    

}