//
//  WebsiteController.swift
//  App
//
//  Created by Artem Panasenko on 11.04.2020.
//

import Vapor
import Leaf
import Authentication
import SendGrid

struct WebsiteController: RouteCollection {
    
    let imageFolder = "ProfilePictures/"
    
    func boot(router: Router) throws {
        
        
        //        This middleware reads the cookie from the request and looks up the session ID in the application’s session list. If the session contains a user, AuthenticationSessionsMiddleware adds it to the AuthenticationCache, making the user available later in the process.
        
        let authSessionRoutes = router.grouped(User.authSessionsMiddleware())
        
        authSessionRoutes.get(use: indexHandler)
        authSessionRoutes.get("acronyms", Acronym.parameter, use: acronymHandler)
        authSessionRoutes.get("users", User.parameter, use: userHandler)
        authSessionRoutes.get("users", use: allUsersHandler)
        authSessionRoutes.get("categories", use: allCategoriesHandler)
        authSessionRoutes.get("categories", Category.parameter, use: categoryHandler)
        
        authSessionRoutes.get("login", use: loginHandler)
        authSessionRoutes.post(LoginPostData.self, at: "login", use: loginPostHandler)
        authSessionRoutes.post("logout", use: logoutHandler)
        authSessionRoutes.get("register", use: registerHandler)
        authSessionRoutes.post(RegisterData.self, at: "register", use: registerPostHandler)
        authSessionRoutes.get("forgottenPassword", use: forgottenPasswordHandler)
        authSessionRoutes.post("forgottenPasswordConfirmed", use: forgottenPasswordPostHandler)
        authSessionRoutes.get("resetPassword", use: resetPasswordHandler)
        authSessionRoutes.post(ResetPasswordData.self, at: "resetPassword", use: resetPasswordPostHandler)
        authSessionRoutes.get("users", User.parameter, "profilePicture", use: getUsersProfilePictureHandler)
        
        // «This creates a new route group, extending from authSessionRoutes, that includes RedirectMiddleware. The application runs a request through RedirectMiddleware before it reaches the route handler, but after AuthenticationSessionsMiddleware. This allows RedirectMiddleware to check for an authenticated user. RedirectMiddleware requires you to specify the path for redirecting »
        
        let protectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<User>(path: "/login"))
        
        protectedRoutes.get("acronyms", "create", use: createAcronymHandler)
        protectedRoutes.post(CreateAcronymData.self, at: "acronyms", "create", use: createAcronymPostHandler)
        protectedRoutes.get("acronyms", Acronym.parameter, "edit", use: editAcronymHandler)
        protectedRoutes.post("acronyms", Acronym.parameter, "edit", use: editAcronymPostHandler)
        protectedRoutes.post("acronyms", Acronym.parameter, "delete", use: deleteAcronymHandler)
        protectedRoutes.get("users", User.parameter, "addProfilePicture", use: addProfilePictureHandler)
        
        
        
    }
    
    func indexHandler(_ req: Request) throws -> Future<View> {
        return Acronym.query(on: req).all().flatMap(to: View.self) { acronyms in
            let userLoggedIn = try req.isAuthenticated(User.self)
            let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
            let context = IndexContext(
                title: "Home page",
                acronyms: acronyms,
                userLoggedIn: userLoggedIn,
                showCookieMessage: showCookieMessage)
            return try req.view().render("index", context)
        }
    }
    
    func acronymHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(Acronym.self).flatMap(to: View.self) { acronym in
            let categories = try acronym.categories.query(on: req).all()
            return acronym.user.get(on: req).flatMap(to: View.self) { user in
                let context = AcronymContext(title: acronym.short, acronym: acronym, user: user, categories: categories)
                return try req.view().render("acronym", context)
            }
        }
    }
    
    func userHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(User.self).flatMap(to: View.self) { user in
            return try user.acronyms.query(on: req).all().flatMap(to: View.self) { acronyms in
                let loggedInUser = try req.authenticated(User.self)
                let context = UserContext(title: user.name, user: user, acronyms: acronyms, authenticatedUser: loggedInUser)
                return try req.view().render("user", context)
            }
        }
    }
    
    func allUsersHandler(_ req: Request) throws -> Future<View> {
        return User.query(on: req).all().flatMap(to: View.self) { users in
            let context = AllUsersContext(title: "All Users", users: users)
            return try req.view().render("allUsers", context)
        }
    }
    
    func allCategoriesHandler(_ req: Request) throws -> Future<View> {
        let categories = Category.query(on: req).all()
        let context = AllCategoriesContext(categories: categories)
        return try req.view().render("allCategories", context)
    }
    
    func categoryHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(Category.self).flatMap(to: View.self) { category in
            let acronyms = try category.acronyms.query(on: req).all()
            let context = CategoryContext(title: category.name, category: category, acronyms: acronyms)
            return try req.view().render("category", context)
        }
    }
    
    func createAcronymHandler(_ req: Request) throws -> Future<View> {
        //        let context = CreateAcronymContext()
        let token = try CryptoRandom()
            .generateData(count: 16)
            .base64EncodedString()
        let context = CreateAcronymContext(csrfToken: token)
        try req.session()["CSRF_TOKEN"] = token
        return try req.view().render("createAcronym", context)
    }
    
    //    func createAcronymPostHandler(_ req: Request, acronym: Acronym) throws -> Future<Response> {
    //        return acronym.save(on: req).map(to: Response.self) { acronym in
    //            guard let id = acronym.id else { throw Abort(.internalServerError) }
    //            return req.redirect(to: "/acronyms/\(id)")
    //        }
    //    }
    
    func editAcronymHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(Acronym.self).flatMap(to: View.self) { acronym in
            let categories = try acronym.categories.query(on: req).all()
            let context = EditAcronymContext(acronym: acronym, categories: categories)
            return try req.view().render("createAcronym", context)
        }
    }
    
    //    func editAcronymPostHandler(_ req: Request) throws -> Future<Response> {
    //        return try flatMap(to: Response.self, req.parameters.next(Acronym.self), req.content.decode(Acronym.self)) { acronym, data in
    //            acronym.short = data.short
    //            acronym.long = data.long
    //            acronym.userID = data.userID
    //
    //            guard let id = acronym.id else {throw Abort(.internalServerError)}
    //            let redirect = req.redirect(to: "/acronyms/\(id)")
    //            return acronym.save(on: req).transform(to: redirect)
    //        }
    //    }
    
    func editAcronymPostHandler(_ req: Request) throws -> Future<Response> {
        // 1
        return try flatMap(to: Response.self, req.parameters.next(Acronym.self), req.content.decode(CreateAcronymData.self)) { acronym, data in
            acronym.short = data.short
            acronym.long = data.long
            let user = try req.requireAuthenticated(User.self)
            acronym.userID = try user.requireID()
            
            guard let id = acronym.id else { throw Abort(.internalServerError) }
            // 2
            return acronym.save(on: req).flatMap(to: [Category].self) { _ in
                // 3
                try acronym.categories.query(on: req).all()
            }
            .flatMap(to: Response.self) { existingCategories in
                print("existingCategories : \(existingCategories)")
                // 4
                let existingStringArray = existingCategories.map { $0.name }
                // 5
                let existingSet = Set<String>(existingStringArray)
                let newSet = Set<String>(data.categories ?? [])
                // 6
                let categoriesToAdd = newSet.subtracting(existingSet)
                let categoriesToRemove = existingSet.subtracting(newSet)
                // 7
                var categoryResults: [Future<Void>] = []
                // 8
                for newCategory in categoriesToAdd {
                    categoryResults.append( try Category.addCategory(newCategory, to: acronym, on: req))
                }
                // 9
                for categoryNameToRemove in categoriesToRemove {
                    // 10
                    let categoryToRemove = existingCategories.first { $0.name == categoryNameToRemove }
                    // 11
                    if let category = categoryToRemove { categoryResults.append(acronym.categories.detach(category, on: req))
                    }
                }
                let redirect = req.redirect(to: "/acronyms/\(id)")
                // 12
                return categoryResults.flatten(on: req).transform(to: redirect)
            }
        }
    }
    
    func deleteAcronymHandler(_ req: Request) throws -> Future<Response> {
        return try req.parameters.next(Acronym.self).delete(on: req)
            .transform(to: req.redirect(to: "/"))
    }
    
    func createAcronymPostHandler(_ req: Request, data: CreateAcronymData) throws -> Future<Response> {
        let expectedToken = try req.session()["CSRF_TOKEN"]
        try req.session()["CSRF_TOKEN"] = nil
        guard let csrfToken = data.csrfToken,
            expectedToken == csrfToken else {
                throw Abort(.badRequest)
        }
        let user = try req.requireAuthenticated(User.self)
        let acronym = try Acronym(short: data.short, long: data.long, userID: user.requireID())
        
        return acronym.save(on: req).flatMap(to: Response.self) { acronym in
            guard let id = acronym.id else {throw Abort(.internalServerError)}
            var categorySaves: [Future<Void>] = []
            for category in data.categories ?? [] {
                try categorySaves.append(Category.addCategory(category, to: acronym, on: req))
            }
            let redirect = req.redirect(to: "/acronyms/\(id)")
            return categorySaves.flatten(on: req).transform(to: redirect)
        }
    }
    
    func loginHandler(_ req: Request) throws -> Future<View> {
        let context: LoginContext
        if req.query[Bool.self, at: "error"] != nil {
            context = LoginContext(loginError: true)
        } else {
            context = LoginContext()
        }
        return try req.view().render("login", context)
    }
    
    func loginPostHandler(_ req: Request, userData: LoginPostData) throws -> Future<Response> {
        return User.authenticate(username: userData.username, password: userData.password, using: BCryptDigest(), on: req).map(to: Response.self) { user in
            guard let user = user  else {
                return req.redirect(to: "/login?error")
            }
            try req.authenticate(user)
            return req.redirect(to: "/")
        }
    }
    
    func logoutHandler(_ req: Request) throws -> Response {
        try req.unauthenticateSession(User.self)
        return req.redirect(to: "/")
    }
    
    func registerHandler(_ req: Request) throws -> Future<View> {
        let context: RegisterContext
        if let message = req.query[String.self, at: "message"] {
            context = RegisterContext(message: message)
        } else {
            context = RegisterContext()
        }
        return try req.view().render("register", context)
    }
    
    func registerPostHandler(_ req: Request, data: RegisterData) throws -> Future<Response> {
        do {
            try data.validate()
        } catch (let error) {
            let redirect: String
            if let error = error as? ValidationError,
                let message = error.reason.addingPercentEncoding(
                    withAllowedCharacters: .urlQueryAllowed) {
                redirect = "/register?message=\(message)"
            } else {
                redirect = "/register?message=Unknown+error"
            }
            return req.future(req.redirect(to: redirect))
        }
        
        let password = try BCrypt.hash(data.password)
        let user = User(name: data.name, username: data.username, password: password, email: data.emailAddress)
        return user.save(on: req).map(to: Response.self) { user in
            try req.authenticateSession(user)
            return req.redirect(to: "/")
        }
    }
    
    func forgottenPasswordHandler(_ req: Request) throws -> Future<View> {
        return try req.view().render(
            "forgottenPassword",
            ["title": "Reset Your Password"])
    }
    
    func forgottenPasswordPostHandler(_ req: Request) throws -> Future<View> {
        let email = try req.content.syncGet(String.self, at: "email")
        return User.query(on: req)
            .filter(\.email == email)
            .first()
            .flatMap(to: View.self) { user in
                guard let user = user else {
                    return try req.view().render("forgottenPasswordConfirmed", ["title": "Password Reset Email Sent"])
                }
                // 2
                let resetTokenString = try CryptoRandom()
                    .generateData(count: 32)
                    .base32EncodedString()
                // 3
                let resetToken = try ResetPasswordToken(token: resetTokenString, userID: user.requireID())
                // 4
                return resetToken.save(on: req).flatMap(to: View.self) { _ in
                    // 5
                    let emailContent = """
                    <p>You've requested to reset your password. <a
                    href="http://localhost:8080/resetPassword?\
                    token=\(resetTokenString)">
                    Click here</a> to reset your password.</p>
                    """
                    // 6
                    let emailAddress = EmailAddress(email: user.email, name: user.name)
                    let fromEmail = EmailAddress(email: "0xtimc@gmail.com", name: "Vapor TIL")
                    // 7
                    let emailConfig = Personalization(to: [emailAddress], subject: "Reset Your Password")
                    // 8
                    let email = SendGridEmail(personalizations: [emailConfig], from: fromEmail, content: [
                        ["type": "text/html",
                         "value": emailContent]
                    ])
                    // 9
                    let sendGridClient = try req.make(SendGridClient.self)
                    return try sendGridClient.send([email], on: req.eventLoop)
                        .flatMap(to: View.self) { _ in
                            // 10
                            return try req.view().render("forgottenPasswordConfirmed", ["title": "Password Reset Email Sent"])
                            
                    }
                }
                
        }
    }
        
    func resetPasswordHandler(_ req: Request)throws -> Future<View> {
        // 1
        guard let token = req.query[String.self, at: "token"] else {
            return try req.view().render("resetPassword", ResetPasswordContext(error: true))
        }
        // 2
        return ResetPasswordToken.query(on: req)
            .filter(\.token == token)
            .first()
            .map(to: ResetPasswordToken.self) { token in
                // 3
                guard let token = token else {  throw Abort.redirect(to: "/") }
                return token
        }.flatMap { token in
            // 4
            return token.user.get(on: req).flatMap { user in
                try req.session().set("ResetPasswordUser", to: user)
                // 5
                return token.delete(on: req)
            }
        }.flatMap {
            // 6
            try req.view().render("resetPassword", ResetPasswordContext())
        }
    }
    
    func resetPasswordPostHandler(_ req: Request, data: ResetPasswordData) throws -> Future<Response> {
        // 2
        guard data.password == data.confirmPassword else {
          return try req.view().render("resetPassword", ResetPasswordContext(error: true))
            .encode(for: req)
        }
        // 3
        let resetPasswordUser = try req.session()
          .get("ResetPasswordUser", as: User.self)
        try req.session()["ResetPasswordUser"] = nil
        // 4
        let newPassword = try BCrypt.hash(data.password)
        resetPasswordUser.password = newPassword
        // 5
        return resetPasswordUser
          .save(on: req)
          .transform(to: req.redirect(to: "/login"))
    }
    
    func addProfilePictureHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(User.self)
          .flatMap { user in
            try req.view().render("addProfilePicture", ["title": "Add Profile Picture", "username": user.name])
       }
    }
    
    func addProfilePicturePostHandler(_ req: Request) throws -> Future<Response> {
        return try flatMap(
          to: Response.self,
          req.parameters.next(User.self),
          req.content.decode(ImageUploadData.self)) { user, imageData in
            let workPath = try req.make(DirectoryConfig.self).workDir
            let name = try "\(user.requireID())-\(UUID().uuidString).jpg"
            let path = workPath + self.imageFolder + name
            FileManager().createFile(atPath: path, contents: imageData.picture, attributes: nil)
            user.profilePicture = name
            let redirect = try req.redirect(to: "/users/\(user.requireID())")
            return user.save(on: req).transform(to: redirect)
        }
    }
    
    func getUsersProfilePictureHandler(_ req: Request) throws -> Future<Response> {
        return try req.parameters.next(User.self)
          .flatMap(to: Response.self) { user in
            guard let filename = user.profilePicture else {
              throw Abort(.notFound)
            }
            let path = try req.make(DirectoryConfig.self).workDir + self.imageFolder + filename
          return try req.streamFile(at: path)
        }
    }
    
}


struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]
    let userLoggedIn: Bool
    let showCookieMessage: Bool
}

struct AcronymContext: Encodable {
    let title: String
    let acronym: Acronym
    let user: User
    let categories: Future<[Category]>
}

struct UserContext: Encodable {
    let title: String
    let user: User
    let acronyms: [Acronym]
    let authenticatedUser: User?
}

struct AllUsersContext: Encodable {
    let title: String
    let users: [User]
}

struct AllCategoriesContext: Encodable {
    let title = "All Categories"
    let categories: Future<[Category]>
}

struct CategoryContext: Encodable {
    let title: String
    let category: Category
    let acronyms: Future<[Acronym]>
}

struct CreateAcronymContext: Encodable {
    let title = "Create An Acronym"
    //    let users: Future<[User]>
    
    let csrfToken: String
}

struct EditAcronymContext: Encodable {
    let title = "Edit Acronym"
    let acronym: Acronym
    //    let users: Future<[User]>
    let categories: Future<[Category]>
    let editing = true
}

struct CreateAcronymData: Content {
    //    let userID: User.ID
    let short: String
    let long: String
    let categories: [String]?
    let csrfToken: String?
}

struct LoginContext: Encodable {
    let title = "Log In"
    let loginError: Bool
    
    init(loginError: Bool = false) {
        self.loginError = loginError
    }
}

struct LoginPostData: Content {
    let username: String
    let password: String
}

struct RegisterContext: Encodable {
    let title = "Register"
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
}

struct RegisterData: Content {
    let name: String
    let username: String
    let password: String
    let confirmPassword: String
    let emailAddress: String
}

extension RegisterData: Validatable, Reflectable {
    
    static func validations() throws -> Validations<RegisterData> {
        var validations = Validations(RegisterData.self)
        try validations.add(\.name, .ascii)
        try validations.add(\.username, .alphanumeric && .count(3...))
        try validations.add(\.password, .count(8...))
        try validations.add(\.emailAddress, .email)
        validations.add("passwords match") { model in
            guard model.password == model.confirmPassword else {
                throw BasicValidationError("passwords don’t match")
            }
        }
        return validations
    }
}

struct ResetPasswordContext: Encodable {
    let title = "Reset Password"
    let error: Bool?
    
    init(error: Bool? = false) {
        self.error = error
    }
}

struct ResetPasswordData: Content {
    let password: String
    let confirmPassword: String
}

struct ImageUploadData: Content {
  var picture: Data
}
