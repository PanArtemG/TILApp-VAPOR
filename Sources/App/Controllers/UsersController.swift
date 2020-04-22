//
//  UsersController.swift
//  App
//
//  Created by Artem Panasenko on 07.04.2020.
//

import Vapor
import Crypto

struct  UsersController: RouteCollection {
    func boot(router: Router) throws {
        let usersRoute = router.grouped("api", "users")
        
        
        usersRoute.get(use: getAllHandler)
        usersRoute.get(User.parameter, use: getHandler)
//        usersRoute.post(User.self, use: createHandler)
        usersRoute.get(User.parameter, "acronyms", use: getAcronymsHandler)
        
        
        
        
//        В этом конкретном случае:
//        - basicAuthMiddleware(using: BCrypt)собирается выполнить фактическую проверку заголовков авторизации.
//        - guardAuthMiddleware гарантирует, что будет выдана ошибка (и возвращен соответствующий код состояния HTTP) в случае сбоя авторизации.
        
        
        let basicAuthMiddleware = User.basicAuthMiddleware(using: BCryptDigest())
        let basicAuthGroup = usersRoute.grouped(basicAuthMiddleware)
        
        basicAuthGroup.post("login", use: loginHandler)
        
//        Мы используем basicAuthMiddleware и guardAuthMiddleware для защиты конечной точки входа в систему, а с другой стороны, мы используем tokenAuthMiddleware и guardAuthMiddleware для защиты наших конечных точек CRUD.
        
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardAuthMiddleware = User.guardAuthMiddleware()
        let tokenAuthGroup = usersRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)
        
        tokenAuthGroup.post(User.self, use: createHandler)
        
//        {
//            "id": "A9652025-D540-4CD3-A986-E35164B6E512",
//            "token": "NwwTeFy8eap0gzk8ATscmg==",
//            "userID": "DC3FC750-4A8A-4C4B-9F99-216156B27F02"
//        }
    
//        «Again, using tokenAuthMiddleware and guardAuthMiddleware ensures only authenticated users can create other users. This prevents anyone from creating a user to send requests to the routes you’ve just protected!
//        Now all API routes that can perform “destructive” actions — that is create, edit or delete resources — are protected. For those actions, the application only accept requests from authenticated users.»
    
    }
    
    
    func getAllHandler(_ req: Request) throws -> Future<[User.Public]> {
        return User.query(on: req).decode(data: User.Public.self).all()
    }
    
    func getHandler(_ req: Request) throws -> Future<User.Public> {
        return try req.parameters.next(User.self).convertToPublic()
    }
    
    func createHandler(_ req: Request, user: User) throws -> Future<User.Public> {
        user.password = try BCrypt.hash(user.password)
        return user.save(on: req).convertToPublic()
    }
    
    func getAcronymsHandler(_ req: Request) throws -> Future<[Acronym]> {
        return try req
            .parameters.next(User.self)
            .flatMap(to: [Acronym].self) { user in
                try user.acronyms.query(on: req).all()
        }
    }
    
    func loginHandler(_ req: Request) throws -> Future<Token> {
        //Get the authenticated user from the request. You’ll protect this route with the HTTP basic authentication middleware. This saves the user’s identity in the request’s authentication cache, allowing you to retrieve the user object later. requireAuthenticated(_:) throws an authentication error if there’s no authenticated user.
        // Получить аунтификацию пользователя
      let user = try req.requireAuthenticated(User.self)
      let token = try Token.generate(for: user)
      return token.save(on: req)
    }
}

