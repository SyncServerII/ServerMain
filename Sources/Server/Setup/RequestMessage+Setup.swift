//
//  RouterRequest.swift
//  Server
//
//  Created by Christopher G Prince on 8/23/20.
//

import Foundation
import ServerShared
import LoggerAPI
import Kitura

extension RequestMessage {
    func setup(routerRequest: RouterRequest) throws {
        if var request = self as? RequestingFileUpload {
            var data = Data()
            request.sizeOfDataInBytes = try routerRequest.read(into: &data)
            request.data = data
            Log.debug("Processed RequestingFileUpload: bytes: \(String(describing: request.sizeOfDataInBytes))")
        }
    }
}
