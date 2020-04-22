//
//  AcronymCategoryPivot.swift
//  App
//
//  Created by Artem Panasenko on 07.04.2020.
//

import FluentPostgreSQL
import Foundation

// 1
final class AcronymCategoryPivot: PostgreSQLUUIDPivot {
  // 2
  var id: UUID?
    
  // 3 Define two properties to link to the IDs of Acronym and Category. This is what holds the relationship.
  var acronymID: Acronym.ID
  var categoryID: Category.ID

  // 4 Define the Left and Right types required by Pivot. This tells Fluent what the two models in the relationship are.
  typealias Left = Acronym
  typealias Right = Category
    
  // 5 Tell Fluent the key path of the two ID properties for each side of the relationship.
  static let leftIDKey: LeftIDKey = \.acronymID
  static let rightIDKey: RightIDKey = \.categoryID

  // 6 Implement the throwing initializer, as required by ModifiablePivot.
  init(_ acronym: Acronym, _ category: Category) throws {
    self.acronymID = try acronym.requireID()
    self.categoryID = try category.requireID()
  }
}

extension AcronymCategoryPivot: Migration {
    static func prepare(
        on connection: PostgreSQLConnection
      ) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
          try addProperties(to: builder)
            
          builder.reference(
            from: \.acronymID,
            to: \Acronym.id,
            onDelete: .cascade)
            
          builder.reference(
            from: \.categoryID,
            to: \Category.id,
            onDelete: .cascade)
        }
      }
}
extension AcronymCategoryPivot: ModifiablePivot {}
