//
//  ResetPasswordController.swift
//  App
//
//  Created by Artem Panasenko on 22.04.2020.
//

import FluentPostgreSQL


final class ResetPasswordToken: Codable {
    var id: UUID?
    var token: String
    var userID: User.ID
    
    init(token: String, userID: User.ID) {
        self.token = token
        self.userID = userID
    }
}

extension ResetPasswordToken: PostgreSQLUUIDModel {}
// 3
extension ResetPasswordToken: Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
            return Database.create(self, on: connection) { builder in
                try addProperties(to: builder)
                builder.reference(from: \.userID, to: \User.id)
            }
    }
}

// 4
extension ResetPasswordToken {
    var user: Parent<ResetPasswordToken, User> {
        return parent(\.userID)
    }
}
