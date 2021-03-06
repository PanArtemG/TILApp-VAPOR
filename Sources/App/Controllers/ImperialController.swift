//
//  ImperialController.swift
//  App
//
//  Created by Artem Panasenko on 22.04.2020.
//

import Vapor
import Imperial
import Authentication

struct ImperialController: RouteCollection {
    func boot(router: Router) throws {
        
        guard let googleCallbackURL =
            Environment.get("GOOGLE_CALLBACK_URL") else {
                fatalError("Google callback URL not set")
        }
        try router.oAuth(from: Google.self, authenticate: "login-google", callback: googleCallbackURL,
                         scope: ["profile", "email"],
                         completion: processGoogleLogin)
        
    }
    
    func processGoogleLogin(request: Request, token: String) throws -> Future<ResponseEncodable> {
        print("GET - request : \(request)")
        print("GET - token : \(token)")
        
        return try Google
            .getUser(on: request)
            .flatMap(to: ResponseEncodable.self) { userInfo in
                
                
                
                print("""
                    GET - userInfo :
                    id : \(userInfo.id)
                    NAME : \(userInfo.name)
                    NAME : \(userInfo.name)
                    NAME : \(userInfo.name)
                    NAME : \(userInfo.name)
                    NAME : \(userInfo.name)
                    NAME : \(userInfo.name)
                    """)
                return User
                    .query(on: request)
                    .filter(\.username == userInfo.email)
                    .first()
                    .flatMap(to: ResponseEncodable.self) { foundUser in
                        guard let existingUser = foundUser else {
                            
                            let user = User(name: userInfo.name, username: userInfo.email, password: UUID().uuidString, email: userInfo.email)
                            return user
                                .save(on: request)
                                .map(to: ResponseEncodable.self) { user in
                                    print("try request.authenticateSession(user) : \(try request.authenticateSession(user))")
                                    try request.authenticateSession(user)
                                    return request.redirect(to: "/")
                            }
                        }
//                        print("GET - existingUser : \(try request.authenticateSession(existingUser))")
                        try request.authenticateSession(existingUser)
                        return request.future(request.redirect(to: "/"))
                }
        }
    }
}


struct GoogleUserInfo: Content {
    let email: String
    let name: String
    let id: String
    let given_name: String
    let family_name: String
    let link: String?
    let picture: String
    let gender: String?
    let locale: String
    
}

extension Google {
    static func getUser(on request: Request) throws -> Future<GoogleUserInfo> {
        print("RUN - getUser()")
        var headers = HTTPHeaders()
        headers.bearerAuthorization = try BearerAuthorization(token: request.accessToken())
        let googleAPIURL =  "https://www.googleapis.com/oauth2/v1/userinfo?alt=json"
        return try request
            .client()
            .get(googleAPIURL, headers: headers)
            .map(to: GoogleUserInfo.self) { response in
                guard response.http.status == .ok else {
                    if response.http.status == .unauthorized {
                        throw Abort.redirect(to: "/login-google")
                    } else {
                        throw Abort(.internalServerError)
                    }
                }
//                print("GET - GoogleUserInfo : \(try response.content.syncDecode(GoogleUserInfo.self))")
                return try response.content.syncDecode(GoogleUserInfo.self)
        }
    }
}
