import FluentPostgreSQL
import Vapor
import Leaf
import Authentication
import SendGrid

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    
    // Register providers first
    try services.register(FluentPostgreSQLProvider())
    try services.register(LeafProvider())
    try services.register(AuthenticationProvider())
    try services.register(SendGridProvider())
    
    
    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)
    
    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    middlewares.use(SessionsMiddleware.self)
    services.register(middlewares)
    
    // Register the configured SQLite database to the database config.
    var databases = DatabasesConfig()
    
    let databaseName: String
    let databasePort: Int
    
    if (env == .testing) {
        databaseName = "vapor-test"
        databasePort = 5433
    } else {
        databaseName = "vapor"
        databasePort = 5432
    }
    
    let databasesConfig = PostgreSQLDatabaseConfig(hostname: "localhost", port: databasePort, username: "vapor", database: databaseName, password: "password")
    let database = PostgreSQLDatabase(config: databasesConfig)
    
    databases.add(database: database, as: .psql)
    services.register(databases)
    
    // Configure migrations
    var migrations = MigrationConfig()
    migrations.add(model: User.self, database: DatabaseIdentifier<User.Database>.psql)
    migrations.add(model: Acronym.self, database: DatabaseIdentifier<Acronym.Database>.psql)
    migrations.add(model: Category.self, database: DatabaseIdentifier<Category.Database>.psql)
    migrations.add(model: AcronymCategoryPivot.self, database: DatabaseIdentifier<AcronymCategoryPivot.Database>.psql)
    migrations.add(model: Token.self, database: DatabaseIdentifier<Token.Database>.psql)
    switch env {
    case .development, .testing:
        migrations.add(migration: AdminUser.self, database: DatabaseIdentifier<AdminUser.Database>.psql)
    default:
        break
    }
    
    migrations.add(migration: ResetPasswordToken.self, database: DatabaseIdentifier<ResetPasswordToken.Database>.psql)
    migrations.add(migration: MakeCategoriesUnique.self, database: DatabaseIdentifier<MakeCategoriesUnique.Database>.psql)
    
    services.register(migrations)
    
    var commandConfig = CommandConfig.default()
    commandConfig.useFluentCommands()
    services.register(commandConfig)
    
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)
    config.prefer(MemoryKeyedCache.self, for: KeyedCache.self)
    
    guard let sendGridAPIKey = Environment.get("SENDGRID_API_KEY") else {
        fatalError("No Send Grid API Key specified")
    }
    let sendGridConfig = SendGridConfig(apiKey: sendGridAPIKey)
    services.register(sendGridConfig)
}
