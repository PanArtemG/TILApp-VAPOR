//
//  User.swift
//  App
//
//  Created by Artem Panasenko on 07.04.2020.
//

import Foundation
import Vapor
import FluentPostgreSQL
import Authentication

final class User: Codable {
    var id: UUID?
    var name: String
    var username: String
    var password: String
    var email: String
    var profilePicture: String?
    
    init(name: String, username: String, password: String, email: String, profilePicture: String? = nil) {
        self.name = name
        self.username = username
        self.password = password
        self.email = email
        self.profilePicture = profilePicture
    }
    
    final class Public: Codable {
        var id: UUID?
        var name: String
        var username: String
        
        init(id: UUID?, name: String, username: String) {
            self.id = id
            self.name = name
            self.username = username
        }
    }
    
}

extension User: PostgreSQLUUIDModel {}
extension User: Content {}
//extension User: Migration {}
extension User: Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            builder.unique(on: \.username)
            builder.unique(on: \.email)
        }
    }
}
extension User: Parameter {}

extension User {
    var acronyms: Children<User, Acronym> {
        return children(\.userID)
    }
}

extension User.Public: Content {}

extension User {
    func convertToPublic() -> User.Public {
        return User.Public(id: id, name: name, username: username)
    }
}

extension Future where T: User {
    func convertToPublic() -> Future<User.Public> {
        return self.map(to: User.Public.self) { user in
            return user.convertToPublic()
        }
    }
}

extension User: BasicAuthenticatable {
    static let usernameKey: UsernameKey = \.username
    static let passwordKey: PasswordKey = \.password
}

extension User: TokenAuthenticatable {
    typealias TokenType = Token
}

struct AdminUser: Migration {
    typealias Database = PostgreSQLDatabase
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        // 4
        let password = try? BCrypt.hash("password")
        guard let hashedPassword = password else {
            fatalError("Failed to create admin user")
        }
        // 5
        let user = User(name: "Admin", username: "admin", password: hashedPassword, email: "admin@localhost.local")
        // 6
        return user.save(on: connection).transform(to: ())
    }
    // 7 Не понятно
    // Реализовать требуемое Revert (on :). .done (on :) возвращает предварительно завершена Future <Void>.
    static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return .done(on: connection)
    }
}

// Coocie Char20
// «Conform User to PasswordAuthenticatable. This allows Vapor to authenticate users with a username and password when they log in. Since you’ve already implemented the necessary properties for PasswordAuthenticatable in BasicAuthenticatable, there’s nothing to do here.
extension User: PasswordAuthenticatable {}
//«Conform User to SessionAuthenticatable. This allows the application to save and retrieve your user as part of a session.
extension User: SessionAuthenticatable {}




//  for admin
//{
//    "id": "4E09F681-2560-4D0D-BDF9-475095879418",
//    "token": "doqQVHtpDUGIpy4ueMXwBQ==",
//    "userID": "F178FB33-1F39-438F-9C7C-522160CF2EDB"
//}
