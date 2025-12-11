/**
 * MongoDB Initialization Script
 * Runs automatically when container starts with empty data directory
 *
 * Usage in docker-compose.yml:
 *   mongo:
 *     image: mongo:7
 *     volumes:
 *       - ./databases/mongo-init.js:/docker-entrypoint-initdb.d/init.js:ro
 *       - mongo-data:/data/db
 *     environment:
 *       MONGO_INITDB_ROOT_USERNAME: ${MONGO_USER:-admin}
 *       MONGO_INITDB_ROOT_PASSWORD: ${MONGO_PASSWORD}
 *       MONGO_INITDB_DATABASE: ${MONGO_DB:-app}
 */

// Switch to app database
db = db.getSiblingDB(process.env.MONGO_INITDB_DATABASE || 'app');

// ===========================================
// Create Application User
// ===========================================

db.createUser({
  user: 'appuser',
  pwd: process.env.MONGO_APP_PASSWORD || 'change_me_in_production',
  roles: [
    { role: 'readWrite', db: process.env.MONGO_INITDB_DATABASE || 'app' }
  ]
});

// ===========================================
// Users Collection
// ===========================================

db.createCollection('users', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['email', 'passwordHash', 'createdAt'],
      properties: {
        email: {
          bsonType: 'string',
          pattern: '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$',
          description: 'Must be a valid email address'
        },
        passwordHash: {
          bsonType: 'string',
          description: 'Hashed password'
        },
        name: {
          bsonType: 'string',
          maxLength: 255
        },
        role: {
          enum: ['user', 'admin', 'moderator'],
          description: 'User role'
        },
        emailVerifiedAt: {
          bsonType: ['date', 'null']
        },
        profile: {
          bsonType: 'object',
          properties: {
            avatar: { bsonType: 'string' },
            bio: { bsonType: 'string', maxLength: 500 },
            preferences: { bsonType: 'object' }
          }
        },
        createdAt: { bsonType: 'date' },
        updatedAt: { bsonType: 'date' },
        deletedAt: { bsonType: ['date', 'null'] }
      }
    }
  }
});

db.users.createIndex({ email: 1 }, { unique: true });
db.users.createIndex({ role: 1 });
db.users.createIndex({ createdAt: -1 });
db.users.createIndex({ deletedAt: 1 }, { partialFilterExpression: { deletedAt: null } });

// ===========================================
// Sessions Collection
// ===========================================

db.createCollection('sessions');

db.sessions.createIndex({ userId: 1 });
db.sessions.createIndex({ token: 1 }, { unique: true });
db.sessions.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 }); // TTL index

// ===========================================
// API Keys Collection
// ===========================================

db.createCollection('apiKeys');

db.apiKeys.createIndex({ userId: 1 });
db.apiKeys.createIndex({ keyHash: 1 }, { unique: true });
db.apiKeys.createIndex({ expiresAt: 1 }, {
  expireAfterSeconds: 0,
  partialFilterExpression: { expiresAt: { $exists: true } }
});

// ===========================================
// Jobs Collection (Background Processing)
// ===========================================

db.createCollection('jobs');

db.jobs.createIndex({ queue: 1, status: 1 });
db.jobs.createIndex({ scheduledAt: 1 }, { partialFilterExpression: { status: 'pending' } });
db.jobs.createIndex({ createdAt: 1 });

// ===========================================
// Audit Logs Collection
// ===========================================

db.createCollection('auditLogs', {
  capped: true,
  size: 104857600, // 100MB
  max: 100000      // Max 100k documents
});

db.auditLogs.createIndex({ userId: 1 });
db.auditLogs.createIndex({ resourceType: 1, resourceId: 1 });
db.auditLogs.createIndex({ createdAt: -1 });

// ===========================================
// Events Collection (Time Series - MongoDB 5.0+)
// ===========================================

// Uncomment for time-series data (analytics, metrics, etc.)
// db.createCollection('events', {
//   timeseries: {
//     timeField: 'timestamp',
//     metaField: 'metadata',
//     granularity: 'seconds'
//   },
//   expireAfterSeconds: 2592000 // 30 days
// });

// ===========================================
// Helper Functions (Stored as documents)
// ===========================================

db.createCollection('_migrations');
db.createCollection('_seeds');

// Track which migrations have run
db._migrations.createIndex({ name: 1 }, { unique: true });

// ===========================================
// Seed Data (Development Only)
// ===========================================

// Uncomment for development environment
// if (process.env.NODE_ENV !== 'production') {
//   db.users.insertMany([
//     {
//       email: 'admin@example.com',
//       passwordHash: '$2b$12$...',
//       name: 'Admin User',
//       role: 'admin',
//       emailVerifiedAt: new Date(),
//       createdAt: new Date(),
//       updatedAt: new Date()
//     },
//     {
//       email: 'user@example.com',
//       passwordHash: '$2b$12$...',
//       name: 'Test User',
//       role: 'user',
//       emailVerifiedAt: new Date(),
//       createdAt: new Date(),
//       updatedAt: new Date()
//     }
//   ]);
//
//   db._seeds.insertOne({
//     name: 'initial_users',
//     executedAt: new Date()
//   });
// }

// ===========================================
// Read-Only User for Analytics
// ===========================================

// db.createUser({
//   user: 'readonly',
//   pwd: 'readonly_password',
//   roles: [
//     { role: 'read', db: process.env.MONGO_INITDB_DATABASE || 'app' }
//   ]
// });

print('MongoDB initialization complete');
