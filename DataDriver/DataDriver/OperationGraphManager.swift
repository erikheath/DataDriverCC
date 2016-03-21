//
//  OperationGraphManager.swift
//

import CoreData

public class OperationGraphManager: NSObject, NSURLSessionDelegate, NSURLSessionDataDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate  {


    // MARK: Object Life-Cycle

    init (coordinator:PersistentStoreCoordinator) {
        self.coordinator = coordinator
        super.init()
    }

    deinit {
        self.URLSession.invalidateAndCancel()
    }

    // MARK : Properties

    let URLConfiguration: NSURLSessionConfiguration = {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.timeoutIntervalForRequest = 300
        return configuration
        }()

    let dataRequestQueue: NSOperationQueue = {
        let opQueue = NSOperationQueue()
        opQueue.maxConcurrentOperationCount = 1
        opQueue.name = "com.datadriverlayer.datarequestqueue"

        return opQueue
        }()

    let dataProcessingQueue: NSOperationQueue = {
        let opQueue = NSOperationQueue()
        opQueue.maxConcurrentOperationCount = 1
        opQueue.name = "com.datadriverlayer.dataprocessingqueue"

        return opQueue
        }()

    let sessionQueue: NSOperationQueue = {
        let opQueue = NSOperationQueue()
        opQueue.maxConcurrentOperationCount = 1
        opQueue.name = "com.datadriverlayer.sessionqueue"

        return opQueue
    }()

    var coordinator: PersistentStoreCoordinator

    /*
    TODO: Refer to main storage
    
    */
    public let stackID: String = ""

    var requestCount: Int = 0

    var responseCount: Int = 0


    /**
     The fetch requests dictionary contains all of the requests processed by the coordinator.
     */
    var fetchRequests:Dictionary<NSDate, (entity: NSEntityDescription, predicateString: String?, status: FulfillmentStatus)> = Dictionary()


    // MARK: Post Init Properties

    lazy var URLSession: NSURLSession = { return NSURLSession(configuration: self.URLConfiguration, delegate: self, delegateQueue:self.sessionQueue)
    }()

    // MARK: Operation Management

    func requestNetworkStoreOperations(changeRequests:Array<RemoteStoreRequest>) {
        let lock = NSLock()
        let operation = DataRequestOperation(session: URLSession, requests: changeRequests, graphManager: self)
        lock.lock()
        self.dataRequestQueue.addOperation(operation)
        lock.unlock()
    }


    // MARK: NSURLSessionDelegate
    // TODO: Add kDataRequestErrorNotification

    public func URLSession(session: NSURLSession, didBecomeInvalidWithError error: NSError?) {
        if let wrappedError: NSError = error {
            let userInfoDict:[String: AnyObject] = [kUnderlyingErrorsArrayKey: [wrappedError]]
            NSNotificationCenter.defaultCenter().postNotificationName(kErrorNotification, object: nil, userInfo: userInfoDict)
        }
    }

    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if let wrappedError: NSError = error {
            let userInfoDict:[String: AnyObject] = [kUnderlyingErrorsArrayKey: [wrappedError]]
            NSNotificationCenter.defaultCenter().postNotificationName(kErrorNotification, object: nil, userInfo: userInfoDict)
        }
    }

    public func URLSession(session: NSURLSession, task: NSURLSessionTask, willPerformHTTPRedirection response: NSHTTPURLResponse, newRequest request: NSURLRequest, completionHandler: (NSURLRequest?) -> Void) {
        completionHandler(request)
    }

    // MARK: NSURLSessionDataTaskDelegate

    public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void) {
        completionHandler(.BecomeDownload)
    }

    public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didBecomeDownloadTask downloadTask: NSURLSessionDownloadTask) {

    }

    // TODO: Change the key management strategy so that regular NSFetchRequests can be used
    public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, willCacheResponse proposedResponse: NSCachedURLResponse, completionHandler: (NSCachedURLResponse?) -> Void) {
        // TODO: Change to non optionals
        //        let operation = DataConditionerOperation(parentContext: self.coordinator.primaryBackgroundContext!, requestResponse: nil, data: proposedResponse.data)
        //        self.DataConditionerOperationQueue .addOperation(operation)
        //        completionHandler(self.coordinator.CoordinatorCachingPolicyEnabled ? proposedResponse : nil)
    }

    // Convert all of the operation processor (including default) to be registered with the system.
    public func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {

        if let response = downloadTask.response as? NSHTTPURLResponse, let URLRequest = downloadTask.originalRequest, let context = self.coordinator.dataManager?.networkContext where response.statusCode == 200 {

            if let responseOperation = URLRequest.responseOperation as? String, let stackID = self.coordinator.dataManager?.stackID, let operationProcessor = URLResponseFactory.processor(responseOperation, stackID: stackID) {
                let operation = operationProcessor.process(session, downloadTask: downloadTask, didFinishDownloadingToURL: location, backgroundContext: context)
                let lock = NSLock()
                lock.lock()
                self.dataProcessingQueue.addOperation(operation)
                lock.unlock()

            } else {
                guard let sessionData = NSData(contentsOfURL: location)
                     else {
                        NSNotificationCenter.defaultCenter().postNotificationName(kErrorNotification, object: downloadTask.response, userInfo: nil)
                        return
                }
                let operation = DataConditionerOperation(parentContext: context, data: sessionData, URLRequest: URLRequest, graphManager: self)
                // TODO: Only the big requests cancel any pending operations.
//                if self.DataProcessingQueue.operationCount > 0 {
//                    self.DataProcessingQueue.cancelAllOperations()
//                }
                let lock = NSLock()
                lock.lock()
                self.dataProcessingQueue.addOperation(operation)
                lock.unlock()
            }

        } else {
            NSNotificationCenter.defaultCenter().postNotificationName(kErrorNotification, object: downloadTask.response, userInfo: nil)
        }
        
        
    }
}

