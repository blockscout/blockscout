# Node.js Express Admin Backend

This backend provides the API services for the Uomi Explorer Admin Dashboard.

## Features

- User authentication and authorization with Auth0
- Passwordless login with Magic Links
- Database access to blockchain exploration data
- RESTful API endpoints for admin operations
- Secure password handling
- Rate limiting and security features

## Development Setup

1. Install dependencies:
   ```
   npm install
   ```

2. Set up environment variables:
   Copy `.env.example` to `.env` and configure the variables.

3. Auth0 Configuration:
   - Create an Auth0 account at https://auth0.com
   - Create a new API and Application in Auth0
   - Configure the Passwordless Email Connection
   - Update the Auth0 settings in `.env`:
     - AUTH0_DOMAIN
     - AUTH0_CLIENT_ID
     - AUTH0_CLIENT_SECRET
     - AUTH0_AUDIENCE
     - AUTH0_CALLBACK_URL
     - AUTH0_LOGOUT_URL

4. Start the development server:
   ```
   npm start
   ```

## API Endpoints

- `POST /api/auth/passwordless/start` - Start passwordless login flow
- `GET /api/auth/status` - Check authentication status
- `GET /api/auth/me` - Get current user
- `GET /api/dashboard/stats` - Get dashboard statistics
- `GET /api/transactions` - List transactions
- `GET /api/blocks` - List blocks
- `GET /api/users` - Manage users (admin only)

## Database

The API connects to the existing PostgreSQL database from the Uomi Explorer, utilizing the `users` and `administrators` tables for user management.
