//
//  CreateRoutes.swift
//  Server
//
//  Created by Christopher Prince on 6/2/17.
//
//

import Foundation
import Kitura
import ServerShared
import LoggerAPI

class CreateRoutes {
    private var router = Router()
    let services: Services
    let db: Database
    
    init(services: Services, db: Database) {
        self.db = db
        self.services = services
    }
    
    func addRoute(ep:ServerEndpoint, processRequest: @escaping ProcessRequest) {
        func handleRequest(routerRequest:RouterRequest, routerResponse:RouterResponse) {
            Log.info("parsedURL: \(routerRequest.parsedURL)")
            let handler = RequestHandler(request: routerRequest, response: routerResponse, services: services, db: db, endpoint:ep)
            
            func create(routerRequest: RouterRequest) -> RequestMessage? {
                let queryDict = routerRequest.queryParameters
                guard let request = try? ep.requestMessageType.decode(queryDict) else {
                    Log.error("Error doing request decode")
                    return nil
                }
                
                do {
                    try request.setup(routerRequest: routerRequest)
                } catch (let error) {
                    Log.error("Error doing request setup: \(error)")
                    return nil
                }
                
                guard request.valid() else {
                    Log.error("Error: Request is not valid.")
                    return nil
                }
                
                return request
            }
            
            handler.doRequest(createRequest: create, processRequest: processRequest)
        }
        
        switch (ep.method) {
        case .get:
            self.router.get(ep.pathWithSuffixSlash) { routerRequest, routerResponse, _ in
                handleRequest(routerRequest: routerRequest, routerResponse: routerResponse)
            }
            
        case .post:
            self.router.post(ep.pathWithSuffixSlash) { routerRequest, routerResponse, _ in
                handleRequest(routerRequest: routerRequest, routerResponse: routerResponse)
            }
        
        case .patch:
            self.router.patch(ep.pathWithSuffixSlash) { routerRequest, routerResponse, _ in
                handleRequest(routerRequest: routerRequest, routerResponse: routerResponse)
            }
        
        case .delete:
            self.router.delete(ep.pathWithSuffixSlash) { routerRequest, routerResponse, _ in
                handleRequest(routerRequest: routerRequest, routerResponse: routerResponse)
            }
        }
    }
    
    func getRoutes() -> Router {
        ServerSetup.credentials(self.router, proxyRouter: self, accountManager: services.accountManager)
        ServerRoutes.add(proxyRouter: self)

        self.router.error {[unowned self] request, response, _ in
            let handler = RequestHandler(request: request, response: response, services: self.services, db: self.db)
            
            let errorDescription: String
            if let error = response.error {
                errorDescription = "\(error)"
            } else {
                errorDescription = "Unknown error"
            }
            
            let message = "Server error: \(errorDescription)"
            handler.failWithError(message: message)
        }

        self.router.all { request, response, _ in
            let handler = RequestHandler(request: request, response: response, services: self.services, db: self.db)
            let message = "Route not found in server: \(request.originalURL)"
            response.statusCode = .notFound
            handler.failWithError(message: message)
        }
        
        return self.router
    }
}

