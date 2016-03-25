//
//  TransactionDelegate.swift
//  DataDriver
//
//  Created by ERIKHEATH A THOMAS on 3/24/16.
//  Copyright © 2016 Curated Cocoa LLC. All rights reserved.
//

import Foundation

@objc protocol TransactionDelegate: NSObjectProtocol {

    optional func URLSession(transaction: TransactionOperation, defaultURLSession: NSURLSession) -> NSURLSession

}