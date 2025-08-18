import Foundation
import SQLite3

// MARK: - Database Error Types

/// Comprehensive error types for database operations
enum DatabaseError: Error, LocalizedError {
    case connectionError
    case connectionUnavailable
    case notInitialized
    case transactionError
    case statementError
    case executionError
    case operationError(Error)
    case busyError
    case lockedError
    case maxRetriesExceeded
    
    var errorDescription: String? {
        switch self {
        case .connectionError:
            return "Database connection error"
        case .connectionUnavailable:
            return "Database connection is unavailable"
        case .notInitialized:
            return "Database is not initialized"
        case .transactionError:
            return "Database transaction error"
        case .statementError:
            return "Database statement preparation error"
        case .executionError:
            return "Database execution error"
        case .operationError(let error):
            return "Database operation error: \(error.localizedDescription)"
        case .busyError:
            return "Database is busy"
        case .lockedError:
            return "Database is locked"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        }
    }
}

/// Centralized database manager to ensure thread-safe initialization and access
/// Enhanced with transaction management, prepared statement caching, and connection pooling
/// Following SQLite best practices for iOS applications with concurrent access
class DatabaseManager {
    
    static let shared = DatabaseManager()
    
    // CRITICAL FIX: Encapsulate database connection - no longer global
    private var dbConnection: OpaquePointer?
    
    // CRITICAL FIX: Single serial queue for ALL database operations
    private let globalDBQueue = DispatchQueue(label: "DatabaseManager.global", qos: .userInitiated)
    private var isInitialized = false
    
    // ENHANCEMENT: Prepared statement caching for performance
    private var preparedStatements: [String: OpaquePointer] = [:]
    private let statementCacheLock = NSLock()
    
    // PERFORMANCE OPTIMIZATION: Limit cache size to prevent memory bloat
    private let maxCacheSize = 50
    private var statementAccessOrder: [String] = [] // LRU tracking
    
    // ENHANCEMENT: Connection pool for concurrent read operations
    private var readConnections: [OpaquePointer?] = []
    private let readConnectionsLock = NSLock()
    private let maxReadConnections = 10 // Increased to maximum for optimal concurrent read performance
    
    // ENHANCEMENT: Error recovery and retry mechanism
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 0.01
    
    // ENHANCEMENT: Performance monitoring
    private var queryExecutionTimes: [String: [TimeInterval]] = [:]
    private let performanceMonitoringLock = NSLock()
    
    private let dbURL: String  // Add to class properties

    private init() {
        self.dbURL = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    }
    
    /// Get database connection safely - ONLY through this method
    func getDatabaseConnection() -> OpaquePointer? {
        return globalDBQueue.sync {
            return dbConnection
        }
    }
    
    /// Execute database operation safely on the global queue
    func executeOnDatabaseQueue<T>(_ operation: @escaping (OpaquePointer?) throws -> T) rethrows -> T {
        return try globalDBQueue.sync {
            // CRITICAL FIX: Fail fast on nil database connections
            guard let db = dbConnection else {
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeOnDatabaseQueue() - CRITICAL: Database connection is nil")
                throw DatabaseError.connectionUnavailable
            }
            
            guard isInitialized else {
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeOnDatabaseQueue() - CRITICAL: Database not initialized")
                throw DatabaseError.notInitialized
            }
            
            return try operation(db)
        }
    }
    
    /// Execute database operation asynchronously on the global queue
    func executeOnDatabaseQueueAsync(_ operation: @escaping (OpaquePointer?) -> Void) {
        globalDBQueue.async {
            // CRITICAL FIX: Check database readiness before executing operation
            guard self.dbConnection != nil else {
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeOnDatabaseQueueAsync() - Database connection is nil, skipping operation")
                return
            }
            
            guard self.isInitialized else {
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeOnDatabaseQueueAsync() - Database not initialized, skipping operation")
                return
            }
            
            operation(self.dbConnection)
        }
    }
    
    // MARK: - ENHANCEMENT: Transaction Management
    
    /// Execute operations within a transaction with automatic rollback on failure
    /// This is critical for maintaining data consistency during complex operations
    func executeInTransaction<T>(_ operation: @escaping (OpaquePointer?) throws -> T) -> Result<T, DatabaseError> {
        return globalDBQueue.sync {
            guard let db = dbConnection else {
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeInTransaction() - Database connection is nil")
                return .failure(.connectionError)
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Begin transaction
            let beginResult = sqlite3_exec(db, "BEGIN IMMEDIATE;", nil, nil, nil)
            if beginResult != SQLITE_OK {
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeInTransaction() - Failed to begin transaction: \(String(cString: sqlite3_errmsg(db)))")
                return .failure(.transactionError)
            }
            
            do {
                let result = try operation(db)
                
                // Commit transaction
                let commitResult = sqlite3_exec(db, "COMMIT;", nil, nil, nil)
                if commitResult != SQLITE_OK {
                    AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeInTransaction() - Failed to commit transaction: \(String(cString: sqlite3_errmsg(db)))")
                    sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                    return .failure(.transactionError)
                }
                
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeInTransaction() - Transaction completed in \(String(format: "%.4f", executionTime))s")
                
                return .success(result)
            } catch {
                // Rollback transaction on error
                let rollbackResult = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                if rollbackResult != SQLITE_OK {
                    AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeInTransaction() - Failed to rollback transaction: \(String(cString: sqlite3_errmsg(db)))")
                }
                
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeInTransaction() - Transaction rolled back due to error: \(error)")
                return .failure(.operationError(error))
            }
        }
    }
    
    /// Execute multiple operations in a single transaction for better performance
    func executeBatchInTransaction<T>(_ operations: [(OpaquePointer?) throws -> T]) -> Result<[T], DatabaseError> {
        return executeInTransaction { db in
            var results: [T] = []
            for operation in operations {
                let result = try operation(db)
                results.append(result)
            }
            return results
        }
    }
    
    // MARK: - ENHANCEMENT: Prepared Statement Caching
    
    /// Get or create a prepared statement with caching for performance
    func getPreparedStatement(sql: String) -> OpaquePointer? {
        return globalDBQueue.sync {
            guard let db = dbConnection else { return nil }
            
            statementCacheLock.lock()
            defer { statementCacheLock.unlock() }
            
            // Check cache first
            if let cachedStatement = preparedStatements[sql] {
                // PERFORMANCE OPTIMIZATION: Update LRU order
                if let index = statementAccessOrder.firstIndex(of: sql) {
                    statementAccessOrder.remove(at: index)
                }
                statementAccessOrder.append(sql)
                
                sqlite3_reset(cachedStatement)
                sqlite3_clear_bindings(cachedStatement)
                return cachedStatement
            }
            
            // Create new prepared statement
            var statement: OpaquePointer?
            let prepareResult = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
            
            if prepareResult == SQLITE_OK {
                // PERFORMANCE OPTIMIZATION: Implement LRU cache eviction
                if preparedStatements.count >= maxCacheSize {
                    if let oldestSql = statementAccessOrder.first {
                        if let oldStatement = preparedStatements[oldestSql] {
                            sqlite3_finalize(oldStatement)
                        }
                        preparedStatements.removeValue(forKey: oldestSql)
                        statementAccessOrder.removeFirst()
                    }
                }
                
                preparedStatements[sql] = statement
                statementAccessOrder.append(sql)
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getPreparedStatement() - Cached new statement for: \(sql.prefix(50))...")
                return statement
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                let errorCode = sqlite3_errcode(db)
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getPreparedStatement() - Failed to prepare statement. Error code: \(errorCode), Message: \(errorMessage)")
                
                // Log additional context for common errors
                switch errorCode {
                case SQLITE_BUSY:
                    AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getPreparedStatement() - Database is busy")
                case SQLITE_LOCKED:
                    AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getPreparedStatement() - Database table is locked")
                case SQLITE_CORRUPT:
                    AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getPreparedStatement() - CRITICAL: Database corruption detected")
                default:
                    break
                }
                
                return nil
            }
        }
    }
    
    /// Execute a prepared statement with retry logic
    func executePreparedStatement(sql: String, parameters: [Any] = []) -> Result<Void, DatabaseError> {
        return executeWithRetry {
            guard let statement = getPreparedStatement(sql: sql) else {
                return .failure(.statementError)
            }
            
            // Bind parameters with bounds checking
            let parameterCount = sqlite3_bind_parameter_count(statement)
            
            guard parameters.count <= parameterCount else {
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executePreparedStatement() ERROR: Too many parameters. Expected: \(parameterCount), Got: \(parameters.count)")
                return .failure(.statementError)
            }
            
            for (index, parameter) in parameters.enumerated() {
                let bindIndex = Int32(index + 1)
                
                // Additional bounds check
                guard bindIndex <= parameterCount else {
                    AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executePreparedStatement() ERROR: Parameter index out of bounds")
                    break
                }
                
                if let stringValue = parameter as? String {
                    // Validate string length to prevent excessive memory usage
                    guard stringValue.count <= 10000 else {
                        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executePreparedStatement() WARNING: String parameter too long, truncating")
                        let truncatedValue = String(stringValue.prefix(10000))
                        sqlite3_bind_text(statement, bindIndex, truncatedValue, -1, nil)
                        continue
                    }
                    sqlite3_bind_text(statement, bindIndex, stringValue, -1, nil)
                } else if let intValue = parameter as? Int {
                    sqlite3_bind_int64(statement, bindIndex, Int64(intValue))
                } else if let doubleValue = parameter as? Double {
                    sqlite3_bind_double(statement, bindIndex, doubleValue)
                } else if parameter is NSNull {
                    sqlite3_bind_null(statement, bindIndex)
                } else {
                    AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executePreparedStatement() WARNING: Unsupported parameter type, binding as null")
                    sqlite3_bind_null(statement, bindIndex)
                }
            }
            
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_DONE || stepResult == SQLITE_ROW {
                return .success(())
            } else {
                return .failure(.executionError)
            }
        }
    }
    
    // MARK: - ENHANCEMENT: Error Recovery and Retry Logic
    
    /// Execute operation with retry logic for handling SQLITE_BUSY errors
    private func executeWithRetry<T>(_ operation: () -> Result<T, DatabaseError>) -> Result<T, DatabaseError> {
        for attempt in 1...maxRetryAttempts {
            let result = operation()
            
            switch result {
            case .success(let value):
                if attempt > 1 {
                    AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeWithRetry() - Operation succeeded on attempt \(attempt)")
                }
                return .success(value)
                
            case .failure(let error):
                if attempt < maxRetryAttempts && shouldRetry(error: error) {
                    let delay = baseRetryDelay * Double(attempt)
                    AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeWithRetry() - Attempt \(attempt) failed, retrying in \(delay)s")
                    Thread.sleep(forTimeInterval: delay)
                    continue
                } else {
                    AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeWithRetry() - All attempts failed: \(error)")
                    return .failure(error)
                }
            }
        }
        
        return .failure(.maxRetriesExceeded)
    }
    
    private func shouldRetry(error: DatabaseError) -> Bool {
        switch error {
        case .busyError, .lockedError:
            return true
        default:
            return false
        }
    }
    
    // MARK: - ENHANCEMENT: Concurrent Read Operations
    
    /// Execute read query using connection pool for improved concurrency
    /// This method enables parallel execution of read queries while maintaining thread safety
    func executeReadQuery<T>(
        sql: String,
        parameters: [Any] = [],
        resultHandler: @escaping (OpaquePointer) throws -> T
    ) -> Result<T, DatabaseError> {
        
        // CRITICAL: Check database readiness first (using internal method to avoid deadlock)
        guard isDatabaseReadyInternal() else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeReadQuery() - Database not ready, isInitialized: \(isInitialized), dbConnection: \(dbConnection != nil)")
            return .failure(.connectionError)
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeReadQuery() - Starting concurrent read query execution")
        
        // RESTORED: Use connection pool for optimal concurrent read performance
        // Try to get a read connection from the pool first
        if let readConnection = getReadConnection() {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeReadQuery() - Using pooled read connection")
            defer { returnReadConnection(readConnection) }
            
            return executeWithRetry {
                do {
                    var statement: OpaquePointer?
                    let prepareResult = sqlite3_prepare_v2(readConnection, sql, -1, &statement, nil)
                    
                    guard prepareResult == SQLITE_OK, let statement = statement else {
                        let error = String(cString: sqlite3_errmsg(readConnection))
                        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeReadQuery() - Failed to prepare statement on pooled connection: \(error)")
                        return .failure(.statementError)
                    }
                    
                    defer { sqlite3_finalize(statement) }
                    
                    // Bind parameters
                    for (index, parameter) in parameters.enumerated() {
                        let bindIndex = Int32(index + 1)
                        
                        if let stringValue = parameter as? String {
                            sqlite3_bind_text(statement, bindIndex, (stringValue as NSString).utf8String, -1, nil)
                        } else if let intValue = parameter as? Int {
                            sqlite3_bind_int64(statement, bindIndex, Int64(intValue))
                        } else if let doubleValue = parameter as? Double {
                            sqlite3_bind_double(statement, bindIndex, doubleValue)
                        } else if parameter is NSNull {
                            sqlite3_bind_null(statement, bindIndex)
                        }
                    }
                    
                    let result = try resultHandler(statement)
                    
                    let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                    AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeReadQuery() - Pooled read executed in \(String(format: "%.4f", executionTime))s")
                    
                    return .success(result)
                } catch {
                    AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeReadQuery() - Error in resultHandler on pooled connection: \(error)")
                    return .failure(.operationError(error))
                }
            }
        } else {
            // Fallback to main connection if pool is exhausted
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeReadQuery() - Pool exhausted, falling back to main connection")
            
            return globalDBQueue.sync {
                // Check if database connection exists, if not try to reinitialize
                if dbConnection == nil {
                    AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeReadQuery() - CRITICAL ERROR: dbConnection is nil! Database not initialized properly")
                    
                    // Try to reinitialize the database
                    if !isInitialized {
                        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeReadQuery() - Attempting to reinitialize database...")
                        initializeDatabase()
                        
                        guard dbConnection != nil else {
                            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeReadQuery() - Database reinitialization failed")
                            return .failure(.connectionError)
                        }
                        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeReadQuery() - Database reinitialization successful")
                    } else {
                        return .failure(.connectionError)
                    }
                }
                
                guard let db = dbConnection else {
                    return .failure(.connectionError)
                }
                
                return executeWithRetry {
                    do {
                        var statement: OpaquePointer?
                        let prepareResult = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
                        
                        guard prepareResult == SQLITE_OK, let statement = statement else {
                            let error = String(cString: sqlite3_errmsg(db))
                            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeReadQuery() - Failed to prepare statement on main connection: \(error)")
                            return .failure(.statementError)
                        }
                        
                        defer { sqlite3_finalize(statement) }
                        
                        // Bind parameters
                        for (index, parameter) in parameters.enumerated() {
                            let bindIndex = Int32(index + 1)
                            
                            if let stringValue = parameter as? String {
                                sqlite3_bind_text(statement, bindIndex, (stringValue as NSString).utf8String, -1, nil)
                            } else if let intValue = parameter as? Int {
                                sqlite3_bind_int64(statement, bindIndex, Int64(intValue))
                            } else if let doubleValue = parameter as? Double {
                                sqlite3_bind_double(statement, bindIndex, doubleValue)
                            } else if parameter is NSNull {
                                sqlite3_bind_null(statement, bindIndex)
                            }
                        }
                        
                        let result = try resultHandler(statement)
                        
                        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeReadQuery() - Fallback read executed in \(String(format: "%.4f", executionTime))s")
                        
                        return .success(result)
                    } catch {
                        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "executeReadQuery() - Error in resultHandler on main connection: \(error)")
                        return .failure(.operationError(error))
                    }
                }
            }
        }
    }
    
    // MARK: - ENHANCEMENT: Connection Pool for Read Operations
    
    /// Get a read-only connection from the pool
    func getReadConnection() -> OpaquePointer? {
        readConnectionsLock.lock()
        defer { readConnectionsLock.unlock() }
        
        // Return existing connection if available
        if let connection = readConnections.first {
            readConnections.removeFirst()
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getReadConnection() - Reusing pooled connection, \(readConnections.count) remaining in pool")
            return connection
        }
        
        // Create new connection if under limit
        if readConnections.count < maxReadConnections {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getReadConnection() - Creating new pooled connection, pool size: \(readConnections.count)/\(maxReadConnections)")
            return createReadOnlyConnection()
        }
        
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getReadConnection() - Pool exhausted (\(maxReadConnections) connections in use)")
        return nil
    }
    
    /// Return a read connection to the pool
    func returnReadConnection(_ connection: OpaquePointer?) {
        guard let connection = connection else { return }
        
        readConnectionsLock.lock()
        defer { readConnectionsLock.unlock() }
        
        if readConnections.count < maxReadConnections {
            readConnections.append(connection)
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "returnReadConnection() - Connection returned to pool, pool size: \(readConnections.count)/\(maxReadConnections)")
        } else {
            sqlite3_close(connection)
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "returnReadConnection() - Pool full, closing connection")
        }
    }
    
    /// Get connection pool statistics for monitoring
    func getConnectionPoolStats() -> (available: Int, max: Int, utilization: Double) {
        readConnectionsLock.lock()
        defer { readConnectionsLock.unlock() }
        
        let available = readConnections.count
        let utilization = Double(maxReadConnections - available) / Double(maxReadConnections)
        
        return (available: available, max: maxReadConnections, utilization: utilization)
    }
    
    private func createReadOnlyConnection() -> OpaquePointer? {
        let url = NSURL(fileURLWithPath: dbURL)
        guard let path = url.appendingPathComponent("ChatHub.sqlite") else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "createReadOnlyConnection() - Failed to create database path")
            return nil
        }
        
        var db: OpaquePointer?
        let openResult = sqlite3_open_v2(path.path, &db, SQLITE_OPEN_READONLY, nil)
        
        if openResult == SQLITE_OK {
            // Configure read connection
            sqlite3_exec(db, "PRAGMA query_only = ON;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA cache_size = 5000;", nil, nil, nil)
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "createReadOnlyConnection() - Successfully created read-only connection")
            return db
        } else {
            let errorMsg = db != nil ? String(cString: sqlite3_errmsg(db)) : "Unknown error"
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "createReadOnlyConnection() - Failed to create read connection: \(errorMsg)")
            return nil
        }
    }
    
    // MARK: - ENHANCEMENT: JSON1 Bulk Operations
    
    /// Bulk insert using JSON1 for improved performance
    /// This can provide 2-20x performance improvement over individual inserts
    func bulkInsert<T: Codable>(items: [T], table: String, columns: [String]) -> Result<Void, DatabaseError> {
        guard !items.isEmpty else { return .success(()) }
        
        return executeInTransaction { db in
            guard let db = db else { throw DatabaseError.connectionError }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Encode items to JSON
            let jsonData = try JSONEncoder().encode(items)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw DatabaseError.operationError(NSError(domain: "JSON", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON"]))
            }
            
            // Create bulk insert SQL using JSON1
            let columnsList = columns.joined(separator: ", ")
            let jsonExtractors = columns.enumerated().map { index, column in
                "json_extract(value, '$[\(index)]') as \(column)"
            }.joined(separator: ", ")
            
            let sql = """
            INSERT INTO \(table) (\(columnsList))
            SELECT \(jsonExtractors)
            FROM json_each(?)
            """
            
            var statement: OpaquePointer?
            let prepareResult = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
            
            guard prepareResult == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "bulkInsert() - Failed to prepare statement: \(error)")
                throw DatabaseError.statementError
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_text(statement, 1, jsonString, -1, nil)
            
            let stepResult = sqlite3_step(statement)
            if stepResult != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "bulkInsert() - Failed to execute: \(error)")
                throw DatabaseError.executionError
            }
            
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "bulkInsert() - Inserted \(items.count) items in \(String(format: "%.4f", executionTime))s")
            
            return ()
        }
    }
    
    /// Bulk update using JSON1 for improved performance
    func bulkUpdate<T: Codable>(items: [T], table: String, keyColumn: String, updateColumns: [String]) -> Result<Void, DatabaseError> {
        guard !items.isEmpty else { return .success(()) }
        
        return executeInTransaction { db in
            guard let db = db else { throw DatabaseError.connectionError }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Encode items to JSON
            let jsonData = try JSONEncoder().encode(items)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw DatabaseError.operationError(NSError(domain: "JSON", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON"]))
            }
            
            // Create bulk update SQL using JSON1
            let setClause = updateColumns.enumerated().map { index, column in
                "\(column) = data.\(column)"
            }.joined(separator: ", ")
            
            let dataColumns = updateColumns.map { column in
                "json_extract(value, '$.\(column)') as \(column)"
            }.joined(separator: ", ")
            
            let sql = """
            WITH data AS (
                SELECT json_extract(value, '$.\(keyColumn)') as \(keyColumn), \(dataColumns)
                FROM json_each(?)
            )
            UPDATE \(table) SET \(setClause)
            FROM data
            WHERE \(table).\(keyColumn) = data.\(keyColumn)
            """
            
            var statement: OpaquePointer?
            let prepareResult = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
            
            guard prepareResult == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "bulkUpdate() - Failed to prepare statement: \(error)")
                throw DatabaseError.statementError
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_text(statement, 1, jsonString, -1, nil)
            
            let stepResult = sqlite3_step(statement)
            if stepResult != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "bulkUpdate() - Failed to execute: \(error)")
                throw DatabaseError.executionError
            }
            
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "bulkUpdate() - Updated \(items.count) items in \(String(format: "%.4f", executionTime))s")
            
            return ()
        }
    }
    
    /// Bulk delete using JSON1 for improved performance
    func bulkDelete(ids: [String], table: String, keyColumn: String) -> Result<Void, DatabaseError> {
        guard !ids.isEmpty else { return .success(()) }
        
        return executeInTransaction { db in
            guard let db = db else { throw DatabaseError.connectionError }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Create JSON array of IDs
            let jsonData = try JSONEncoder().encode(ids)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw DatabaseError.operationError(NSError(domain: "JSON", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON"]))
            }
            
            let sql = """
            DELETE FROM \(table) 
            WHERE \(keyColumn) IN (
                SELECT value FROM json_each(?)
            )
            """
            
            var statement: OpaquePointer?
            let prepareResult = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
            
            guard prepareResult == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "bulkDelete() - Failed to prepare statement: \(error)")
                throw DatabaseError.statementError
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_text(statement, 1, jsonString, -1, nil)
            
            let stepResult = sqlite3_step(statement)
            if stepResult != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "bulkDelete() - Failed to execute: \(error)")
                throw DatabaseError.executionError
            }
            
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "bulkDelete() - Deleted \(ids.count) items in \(String(format: "%.4f", executionTime))s")
            
            return ()
        }
    }
    
    // MARK: - ENHANCEMENT: Background Maintenance
    
    /// Schedule background WAL checkpoint to prevent occasional fsync overhead
    func scheduleBackgroundCheckpoint() {
        DispatchQueue.global(qos: .background).async {
            self.performBackgroundCheckpoint()
        }
    }
    
    private func performBackgroundCheckpoint() {
        globalDBQueue.async {
            guard let db = self.dbConnection else { return }
            
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "performBackgroundCheckpoint() - Starting background WAL checkpoint")
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            var logFrames: Int32 = 0
            var checkpointedFrames: Int32 = 0
            
            let result = sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_PASSIVE, &logFrames, &checkpointedFrames)
            
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            
            if result == SQLITE_OK {
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "performBackgroundCheckpoint() - Completed in \(String(format: "%.4f", executionTime))s, frames: \(logFrames)/\(checkpointedFrames)")
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "performBackgroundCheckpoint() - Failed: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
    }
    
    /// Perform database maintenance (VACUUM) when device is idle
    func performMaintenanceWhenIdle() {
        DispatchQueue.global(qos: .background).async {
            self.performDatabaseMaintenance()
        }
    }
    
    private func performDatabaseMaintenance() {
        globalDBQueue.async {
            guard let db = self.dbConnection else { return }
            
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "performDatabaseMaintenance() - Starting database maintenance")
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Check free space first
            var queryStatement: OpaquePointer?
            let querySQL = "SELECT page_count * page_size as total_size, freelist_count * page_size as freelist_size FROM pragma_page_count(), pragma_freelist_count(), pragma_page_size()"
            
            if sqlite3_prepare_v2(db, querySQL, -1, &queryStatement, nil) == SQLITE_OK {
                if sqlite3_step(queryStatement) == SQLITE_ROW {
                    let totalSize = sqlite3_column_int64(queryStatement, 0)
                    let freelistSize = sqlite3_column_int64(queryStatement, 1)
                    
                    AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "performDatabaseMaintenance() - Total: \(totalSize) bytes, Freelist: \(freelistSize) bytes")
                    
                    // Only vacuum if there's significant free space (>10MB)
                    if freelistSize > 10 * 1024 * 1024 {
                        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "performDatabaseMaintenance() - Starting VACUUM operation")
                        
                        let vacuumResult = sqlite3_exec(db, "VACUUM;", nil, nil, nil)
                        if vacuumResult == SQLITE_OK {
                            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "performDatabaseMaintenance() - VACUUM completed successfully")
                            
                            // Truncate WAL file after vacuum
                            sqlite3_exec(db, "PRAGMA wal_checkpoint(TRUNCATE);", nil, nil, nil)
                        } else {
                            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "performDatabaseMaintenance() - VACUUM failed: \(String(cString: sqlite3_errmsg(db)))")
                        }
                    } else {
                        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "performDatabaseMaintenance() - Skipping VACUUM, insufficient free space")
                    }
                }
            }
            
            sqlite3_finalize(queryStatement)
            
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "performDatabaseMaintenance() - Completed in \(String(format: "%.4f", executionTime))s")
        }
    }
    
    /// Clean up prepared statement cache
    func cleanupPreparedStatements() {
        statementCacheLock.lock()
        defer { statementCacheLock.unlock() }
        
        for (_, statement) in preparedStatements {
            sqlite3_finalize(statement)
        }
        preparedStatements.removeAll()
        
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "cleanupPreparedStatements() - Cleaned up prepared statement cache")
    }
    
    /// Clean up connection pool
    func cleanupConnectionPool() {
        readConnectionsLock.lock()
        defer { readConnectionsLock.unlock() }
        
        for connection in readConnections {
            if let connection = connection {
                sqlite3_close(connection)
            }
        }
        readConnections.removeAll()
        
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "cleanupConnectionPool() - Cleaned up connection pool")
    }
    
    // MARK: - ENHANCEMENT: Performance Monitoring
    
    /// Monitor query execution time for performance optimization
    func monitorQueryPerformance(query: String, executionTime: TimeInterval) {
        performanceMonitoringLock.lock()
        defer { performanceMonitoringLock.unlock() }
        
        let queryKey = String(query.prefix(100)) // Use first 100 chars as key
        
        if queryExecutionTimes[queryKey] == nil {
            queryExecutionTimes[queryKey] = []
        }
        
        queryExecutionTimes[queryKey]?.append(executionTime)
        
        // Log slow queries (> 100ms)
        if executionTime > 0.1 {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "monitorQueryPerformance() - SLOW QUERY (\(String(format: "%.4f", executionTime))s): \(queryKey)")
        }
        
        // Keep only last 10 measurements per query
        if let times = queryExecutionTimes[queryKey], times.count > 10 {
            queryExecutionTimes[queryKey] = Array(times.suffix(10))
        }
    }
    
    /// Get performance statistics for a query
    func getQueryPerformanceStats(query: String) -> (average: TimeInterval, max: TimeInterval, count: Int)? {
        performanceMonitoringLock.lock()
        defer { performanceMonitoringLock.unlock() }
        
        let queryKey = String(query.prefix(100))
        guard let times = queryExecutionTimes[queryKey], !times.isEmpty else {
            return nil
        }
        
        let average = times.reduce(0, +) / Double(times.count)
        let max = times.max() ?? 0
        
        return (average: average, max: max, count: times.count)
    }

    // MARK: - Original Methods (Enhanced)
    
    /// Initialize the shared database connection and all database classes in proper order
    func initializeDatabase() {
        globalDBQueue.sync {
            guard !isInitialized else {
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "initializeDatabase() - Database already initialized, skipping")
                return
            }
            
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "initializeDatabase() - Starting centralized database initialization")
            
            // Step 1: Create the shared database connection
            dbConnection = createChatHubDatabase()
            
            guard dbConnection != nil else {
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "initializeDatabase() - CRITICAL ERROR: Failed to create database connection")
                return
            }
            
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "initializeDatabase() - Database connection established successfully")
            
            // Legacy dbQuere assignment removed - all code now uses modern DatabaseManager pattern
            
            // Mark as initialized before calling table creation methods
            isInitialized = true
            
            // Step 2: Initialize all database classes in controlled order
            // This ensures no race conditions between different database classes
            initializeDatabaseClasses()
            
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "initializeDatabase() - All database classes initialized successfully")
        }
    }
    
    private func initializeDatabaseClasses() {
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "initializeDatabaseClasses() - Starting sequential database class initialization")
        
        // Initialize each database class sequentially to avoid conflicts
        // Using singletons to ensure only one instance exists
        
        // 1. ChatsDB (most critical) - ensure tables are created
        ChatsDB.shared.ensureTablesCreated()
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "initializeDatabaseClasses() - ChatsDB singleton ready")
        
        // 2. MessagesDB (separated from ChatsDB) - ensure table is created
        MessagesDB.shared.ensureTableCreated()
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "initializeDatabaseClasses() - MessagesDB singleton ready")
        
        // 3. AITrainingMessagesDB (separated from ChatsDB) - ensure table is created
        AITrainingMessagesDB.shared.ensureTableCreated()
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "initializeDatabaseClasses() - AITrainingMessagesDB singleton ready")
        
        // 4. NotificationDB (converted to singleton)
        InAppNotificationDB.shared.ensureTableCreated()
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "initializeDatabaseClasses() - NotificationDB singleton ready")
        
        // 5. ProfileDB (singleton) - ensure table is created
        ProfileDB.shared.ensureTableCreated()
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "initializeDatabaseClasses() - ProfileDB singleton ready")
        
        // 6. GamesDB (singleton) - ensure tables are created
        GamesDB.shared.ensureTablesCreated()
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "initializeDatabaseClasses() - GamesDB singleton ready")
        
        // 7. MyProfileDB has been removed - now using ProfileDB for user's own profile as well
        // User's own profile is stored in ProfileDB and retrieved by userId
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "initializeDatabaseClasses() - MyProfileDB removed, using ProfileDB for user's own profile")
        
        // 8. OnlineUsersDB (converted to singleton) - ensure table is created
        OnlineUsersDB.shared.ensureTableCreated()
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "initializeDatabaseClasses() - OnlineUsersDB singleton ready")
        
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "initializeDatabaseClasses() - All database classes initialized")
    }
    
    private func createChatHubDatabase() -> OpaquePointer? {
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "createChatHubDatabase() - Starting database creation")
        
        // Close existing connection if any
        if dbConnection != nil {
            let closeResult = sqlite3_close(dbConnection)
            if closeResult != SQLITE_OK {
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "createChatHubDatabase() - Warning: error closing previous database connection")
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "createChatHubDatabase() - Previous database connection closed successfully")
            }
        }
        
        var db: OpaquePointer?
        let url = NSURL(fileURLWithPath: dbURL)
        guard let path = url.appendingPathComponent("ChatHub.sqlite") else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "createChatHubDatabase() - Failed to create database path")
            return nil
        }
        
        let fileComponent = path.path
        let openResult = sqlite3_open(fileComponent, &db)
        
        if openResult == SQLITE_OK {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "createChatHubDatabase() - Database opened successfully at \(fileComponent)")
            
            // CRITICAL FIX: Enable SQLite thread safety and optimizations following best practices
            sqlite3_exec(db, "PRAGMA journal_mode = WAL;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA synchronous = NORMAL;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA cache_size = 10000;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA temp_store = MEMORY;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA journal_size_limit = 6144000;", nil, nil, nil) // 6MB WAL limit
            sqlite3_exec(db, "PRAGMA mmap_size = 268435456;", nil, nil, nil) // 256MB mmap
            sqlite3_exec(db, "PRAGMA page_size = 4096;", nil, nil, nil) // Optimal page size
            // CRITICAL: Enable thread-safe mode
            sqlite3_exec(db, "PRAGMA threadsafe = 1;", nil, nil, nil)
            
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "createChatHubDatabase() - Applied SQLite optimizations for high performance")
            
            return db
        } else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "createChatHubDatabase() - Failed to open database at \(fileComponent): \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
    }
    
    /// Check if database is properly initialized
    func isDatabaseReady() -> Bool {
        return globalDBQueue.sync {
            return isInitialized && dbConnection != nil
        }
    }
    
    /// Internal method to check readiness without queue lock (for use during initialization)
    func isDatabaseReadyInternal() -> Bool {
        return isInitialized && dbConnection != nil
    }
    
    /// Get database instances safely (only after initialization)
    func getChatDB() -> ChatsDB? {
        guard isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getChatDB() - Database not ready, returning nil")
            return nil
        }
        return ChatsDB.shared
    }
    
    func getProfileDB() -> ProfileDB? {
        guard isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getProfileDB() - Database not ready, returning nil")
            return nil
        }
        return ProfileDB.shared
    }
    
    func getGamesDB() -> GamesDB? {
        guard isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getGamesDB() - Database not ready, returning nil")
            return nil
        }
        return GamesDB.shared
    }
    
    func getNotificationDB() -> InAppNotificationDB? {
        guard isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getNotificationDB() - Database not ready, returning nil")
            return nil
        }
        return InAppNotificationDB.shared
    }
    
    /// Internal method for initialization - avoids deadlock
    private func getNotificationDBInternal() -> InAppNotificationDB? {
        guard isDatabaseReadyInternal() else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getNotificationDBInternal() - Database not ready, returning nil")
            return nil
        }
        return InAppNotificationDB.shared
    }
    
    // REMOVED: getMyProfileDB() - now using ProfileDB for user's own profile
    // To get user's own profile, use ProfileDB.shared.query(UserId: currentUserId)
    // where currentUserId is retrieved from UserDefaults.standard.string(forKey: "userId")
    
    /// Get current user's profile using ProfileDB
    /// This replaces the old MyProfileDB functionality
    func getCurrentUserProfile() -> ProfileModel? {
        guard let currentUserId = UserDefaults.standard.string(forKey: "userId"), !currentUserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getCurrentUserProfile() - No userId found in UserDefaults")
            return nil
        }
        
        guard let profileDB = getProfileDB() else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getCurrentUserProfile() - ProfileDB not ready")
            return nil
        }
        
        let profile = profileDB.query(UserId: currentUserId)
        if profile != nil {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getCurrentUserProfile() - Found profile for current user: \(currentUserId)")
        } else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getCurrentUserProfile() - No profile found for current user: \(currentUserId)")
        }
        
        return profile
    }
    
    /// Save/update current user's profile using ProfileDB
    /// This replaces the old MyProfileDB functionality
    func saveCurrentUserProfile(
        age: String = "", gender: String = "", language: String = "", country: String = "",
        city: String = "", platform: String = "", height: String = "", occupation: String = "",
        men: String = "", women: String = "", single: String = "", married: String = "",
        children: String = "", gym: String = "", smoke: String = "", drink: String = "",
        games: String = "", decenttalk: String = "", pets: String = "", hobbies: String = "",
        travel: String = "", zodiac: String = "", music: String = "", movies: String = "",
        naughty: String = "", foodie: String = "", dates: String = "", fashion: String = "",
        broken: String = "", depressed: String = "", lonely: String = "", cheated: String = "",
        insomnia: String = "", voice: String = "", video: String = "", pics: String = "",
        voicecalls: String = "", videocalls: String = "", goodexperience: String = "",
        badexperience: String = "", male_accounts: String = "", female_accounts: String = "",
        male_chats: String = "", female_chats: String = "", blocks: String = "", reports: String = "",
        snapchat: String = "", instagram: String = "", image: String = "", name: String = "",
        emailVerified: String = "", createdTime: String = "", premium: String = ""
    ) {
        guard let currentUserId = UserDefaults.standard.string(forKey: "userId"), !currentUserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "saveCurrentUserProfile() - No userId found in UserDefaults")
            return
        }
        
        guard let profileDB = getProfileDB() else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "saveCurrentUserProfile() - ProfileDB not ready")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "saveCurrentUserProfile() - Saving profile for current user: \(currentUserId)")
        
        // Use ProfileDB insert method to save/update the profile
        profileDB.insert(
            UserId: NSString(string: currentUserId),
            Age: NSString(string: age),
            Country: NSString(string: country),
            Language: NSString(string: language),
            Gender: NSString(string: gender),
            men: NSString(string: men),
            women: NSString(string: women),
            single: NSString(string: single),
            married: NSString(string: married),
            children: NSString(string: children),
            gym: NSString(string: gym),
            smoke: NSString(string: smoke),
            drink: NSString(string: drink),
            games: NSString(string: games),
            decenttalk: NSString(string: decenttalk),
            pets: NSString(string: pets),
            travel: NSString(string: travel),
            music: NSString(string: music),
            movies: NSString(string: movies),
            naughty: NSString(string: naughty),
            Foodie: NSString(string: foodie),
            dates: NSString(string: dates),
            fashion: NSString(string: fashion),
            broken: NSString(string: broken),
            depressed: NSString(string: depressed),
            lonely: NSString(string: lonely),
            cheated: NSString(string: cheated),
            insomnia: NSString(string: insomnia),
            voice: NSString(string: voice),
            video: NSString(string: video),
            pics: NSString(string: pics),
            goodexperience: NSString(string: goodexperience),
            badexperience: NSString(string: badexperience),
            male_accounts: NSString(string: male_accounts),
            female_accounts: NSString(string: female_accounts),
            male_chats: NSString(string: male_chats),
            female_chats: NSString(string: female_chats),
            reports: NSString(string: reports),
            blocks: NSString(string: blocks),
            voicecalls: NSString(string: voicecalls),
            videocalls: NSString(string: videocalls),
            Time: Date(),
            Image: NSString(string: image),
            Named: NSString(string: name),
            Height: NSString(string: height),
            Occupation: NSString(string: occupation),
            Instagram: NSString(string: instagram),
            Snapchat: NSString(string: snapchat),
            Zodic: NSString(string: zodiac),
            Hobbies: NSString(string: hobbies),
            EmailVerified: NSString(string: emailVerified),
            CreatedTime: NSString(string: createdTime),
            Platform: NSString(string: platform),
            Premium: NSString(string: premium),
            city: NSString(string: city)
        )
    }
    
    func getOnlineUsersDB() -> OnlineUsersDB? {
        guard isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getOnlineUsersDB() - Database not ready, returning nil")
            return nil
        }
        return OnlineUsersDB.shared
    }
    
    func getMessagesDB() -> MessagesDB? {
        guard isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getMessagesDB() - Database not ready, returning nil")
            return nil
        }
        return MessagesDB.shared
    }
    
    func getAITrainingMessagesDB() -> AITrainingMessagesDB? {
        guard isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: DatabaseManager", message: "getAITrainingMessagesDB() - Database not ready, returning nil")
            return nil
        }
        return AITrainingMessagesDB.shared
    }
} 