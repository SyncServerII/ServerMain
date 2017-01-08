//
//  ServerRoutes.swift
//  Authentication
//
//  Created by Christopher Prince on 11/26/16.
//
//

import Kitura

public class ServerRoutes {
    class func add(proxyRouter:CreateRoutes) {
        let utilController = UtilController()
        proxyRouter.addRoute(ep: ServerEndpoints.healthCheck, createRequest: HealthCheckRequest.init, processRequest: utilController.healthCheck)
// TODO: Add this when we get the DEBUG flag working
// #if DEBUG
        proxyRouter.addRoute(ep: ServerEndpoints.checkPrimaryCreds, createRequest: CheckPrimaryCredsRequest.init, processRequest: utilController.checkPrimaryCreds)
// #endif

        let userController = UserController()
        proxyRouter.addRoute(ep: ServerEndpoints.addUser, createRequest: AddUserRequest.init, processRequest: userController.addUser)
        proxyRouter.addRoute(ep: ServerEndpoints.checkCreds, createRequest: CheckCredsRequest.init, processRequest: userController.checkCreds)
        proxyRouter.addRoute(ep: ServerEndpoints.removeUser, createRequest: RemoveUserRequest.init, processRequest: userController.removeUser)
    }
}
