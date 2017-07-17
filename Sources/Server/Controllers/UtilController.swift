//
//  UtilController.swift
//  Server
//
//  Created by Christopher Prince on 11/26/16.
//
//

import LoggerAPI
import Credentials
import SyncServerShared

class UtilController : ControllerProtocol {
    class func setup(db:Database) -> Bool {
        return true
    }
    
    init() {
    }
    
    func healthCheck(params:RequestProcessingParameters) {
        let response = HealthCheckResponse()
        params.completion(response)
    }
    
    func checkPrimaryCreds(params:RequestProcessingParameters) {
        let response = CheckPrimaryCredsResponse()
        params.completion(response)
    }
}
