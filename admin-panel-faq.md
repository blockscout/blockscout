# Admin Panel FAQ

## Common Issues and Solutions

### 1. "npm error path /app/package.json"

**Problem**: Docker container can't find the package.json file.

**Solution**:
- The issue is related to volume mounting in Docker Compose.
- Use the `./admin-panel.sh` script which has the correct paths set up.
- Or manually check the volume paths in the Docker Compose files.

**Detailed Fix**:
```bash
# Check your current directory
pwd

# Make sure you are running the command from the repository root directory
cd /Users/lucasimonetti/uomi-explorer

# Use the helper script
./admin-panel.sh start
```

If you need to manually adjust the Docker Compose file, ensure the volume paths are correct:
```yaml
volumes:
  - ../../admin-backend:/app  # If running from docker-compose directory
  # OR
  - ./admin-backend:/app  # If running from root directory
```

### 2. Build Error: "Cannot find module 'chart.js/auto'"

**Problem**: The Chart.js dependency is missing during Docker build.

**Solution**:
1. Ensure Chart.js is installed:
   ```bash
   cd admin-frontend
   npm install chart.js@4 --save
   ```

2. If using Docker, update the Dockerfile to explicitly install Chart.js:
   ```dockerfile
   # In the builder stage
   RUN npm install chart.js@4 --save
   ```

3. Rebuild the container:
   ```bash
   ./admin-panel.sh build
   ```

### 3. Auth0 Configuration Issues

**Problem**: Auth0 passwordless login isn't working.

**Solution**:
1. Run the validation script:
   ```bash
   cd admin-backend
   npm run validate-auth0
   ```

2. Check your Auth0 configuration:
   - Make sure your Auth0 tenant has Email Passwordless Connection enabled
   - Verify your callback URLs are correctly set
   - Check that your environment variables match the Auth0 application settings

3. Common Auth0 issues:
   - Email provider not configured in Auth0
   - Connection not enabled for your application
   - Incorrect client ID or client secret
   - Missing or incorrect redirect URLs

### 3. Database Connection Issues

**Problem**: Backend can't connect to the database.

**Solution**:
1. Check database credentials in your .env file
2. Verify that the database service is running:
   ```bash
   docker ps | grep postgres
   ```
3. If using Docker, ensure networks are configured correctly:
   ```bash
   docker network ls
   docker network inspect blockscout-network
   ```

### 4. Frontend Can't Connect to Backend

**Problem**: Frontend shows "Unable to connect to the server".

**Solution**:
1. Check that both services are running:
   ```bash
   ./admin-panel.sh status
   ```
2. Verify environment variables:
   - Backend: Check PORT variable in admin-backend/.env (should be 4010)
   - Frontend: Check NEXT_PUBLIC_API_URL in admin-frontend/.env.local (should be http://admin-backend:4010 for Docker or http://localhost:4010 for local development)
3. Check network connectivity between containers:
   ```bash
   docker exec -it admin-frontend wget -O- http://admin-backend:4010/health
   ```

### 5. Auth Guard Errors in Frontend

**Problem**: You're stuck in a login loop or getting constant redirects.

**Solution**:
1. Clear browser localStorage:
   - Open Developer Tools (F12)
   - Go to Application tab > Storage > Local Storage
   - Clear all items related to your domain
2. Check Auth0 configuration in the frontend:
   - Verify that NEXT_PUBLIC_AUTH0_DOMAIN and NEXT_PUBLIC_AUTH0_CLIENT_ID match your Auth0 account
   - Make sure NEXT_PUBLIC_AUTH0_REDIRECT_URI is correctly set
3. Check browser console for specific errors

## Maintenance Tasks

### Updating Auth0 Settings

If you need to update Auth0 configurations:

1. Update the .env files in both admin-backend and admin-frontend
2. Restart the services:
   ```bash
   ./admin-panel.sh restart
   ```

### Adding New Admin Users

Currently, new users who sign up through Auth0 are not automatically assigned as administrators. To add a new admin:

1. User should first log in through the passwordless flow
2. Connect to the database and add an entry to the administrators table:
   ```sql
   INSERT INTO administrators (user_id, role, inserted_at, updated_at)
   VALUES ((SELECT id FROM users WHERE email = 'user@example.com'), 'admin', NOW(), NOW());
   ```

### Monitoring Auth Activity

Auth activity is logged to:
- `/app/logs/auth.log` inside the admin-backend container
- Combined logs can be viewed with:
  ```bash
  ./admin-panel.sh logs
  ```
