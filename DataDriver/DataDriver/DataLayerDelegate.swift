//
//  DataLayerDelegate
//  DataDriver
//

import Foundation

@objc public protocol DataLayerDelegate: NSObjectProtocol {

    optional func URLConfiguration(dataLayer: DataLayer, defaultURLConfiguration: NSURLSessionConfiguration) -> NSURLSessionConfiguration

    optional func transactionDelegate(dataLayer: DataLayer, transaction: TransactionOperation) -> TransactionDelegate

}