# Auth0 Passwordless Authentication Troubleshooting Guide

This guide provides instructions for troubleshooting passwordless authentication issues with Auth0 in the Admin Backend.

## Prerequisites

Before using passwordless authentication, ensure the following are configured properly:

1. **Enable Passwordless OTP Grant**:
   - Go to [Auth0 Dashboard](https://manage.auth0.com/#/applications) > Applications > Your Application
   - Navigate to "Advanced Settings" > "Grant Types"
   - Check that "Passwordless OTP" is enabled
   - Also ensure that "Client Credentials" is enabled

2. **Set Up Email Connection**:
   - Go to [Auth0 Dashboard](https://manage.auth0.com/#/connections) > Authentication > Passwordless
   - Make sure "Email" is enabled
   - Click on the "Email" connection and verify that your application is enabled for this connection

3. **Configure Callback URLs**:
   - Go to [Auth0 Dashboard](https://manage.auth0.com/#/applications) > Applications > Your Application > Settings
   - Add your callback URL to "Allowed Callback URLs" (e.g., http://localhost:3010/callback)
   - Add your application URL to "Allowed Web Origins" (e.g., http://localhost:3010)

4. **Verify Environment Variables**:
   - Run `./scripts/validate-auth0-config.sh` to check if all required environment variables are set

## Detailed Configuration Steps

### Step 1: Set up Email Passwordless Connection

1. Log in to your [Auth0 Dashboard](https://manage.auth0.com)
2. Navigate to **Authentication > Passwordless**
3. Enable the **Email** option
4. Click on the **Email** connection to configure it
5. In the settings:
   - Set **Email Syntax**: Email
   - Set **OTP Syntax**: Numeric code
   - Enable **Use Magic Link**
   - Set appropriate **OTP Expiry** (e.g., 300 seconds)
   - Set **OTP Length** (e.g., 6 digits)
6. Under **Applications**, ensure your application is enabled
7. Save changes

### Step 2: Enable Required Grant Types

1. Go to **Applications > Applications** and select your application
2. Go to **Settings > Advanced Settings > Grant Types**
3. Enable the following grant types:
   - **Passwordless OTP**
   - **Client Credentials**
   - **Implicit** (for magic links)
   - **Authorization Code** (recommended)
4. Save changes

### Step 3: Configure Application URLs

1. Still in your application settings, under the **Basic Information** tab
2. Configure the following URLs:
   - **Allowed Callback URLs**: Add `http://localhost:3010/callback` (for local development) and any production URLs
   - **Allowed Logout URLs**: Add `http://localhost:3010` and any production URLs
   - **Allowed Web Origins**: Add `http://localhost:3010` and any production URLs
3. Save changes

## Testing Passwordless Authentication

You can use the test scripts to verify if passwordless authentication is working:

```bash
# Test only sending the passwordless code
cd /Users/jacopomosconi/UOMI-Project/uomi-explorer/admin-backend
node src/test-passwordless.js

# Test the full flow including code verification
node src/test-passwordless-full.js
```

You can also use the validation script which includes a basic API check:

```bash
./scripts/validate-auth0-config.sh
```

## OTP Code vs Magic Link

The system now supports two modes of passwordless authentication:

1. **OTP Code Flow** (Primary method):
   - A numeric code is sent to the user's email
   - The user inputs this code in the application
   - The code is exchanged for authentication tokens
   - This method is more reliable and provides better user experience on mobile devices

2. **Magic Link Flow** (Alternative):
   - A link is sent to the user's email
   - Clicking the link completes authentication
   - This method requires proper redirect URI configuration

To change between methods, adjust the `send` parameter in the authentication call:
- For OTP codes: set `send: 'code'`
- For magic links: set `send: 'link'`

## Common Issues and Solutions

### "Client authentication is required" Error (403)

**Symptoms**: API returns 403 with "unauthorized_client" error and "Client authentication is required" message.

**Solutions**:
1. Make sure "Passwordless OTP" grant type is enabled in Auth0 Dashboard
2. Ensure "Client Credentials" grant type is also enabled
3. Verify client ID and client secret are correct in your .env file
4. Make sure the email connection is set up and enabled for your application

### "Connection not found" Error (400)

**Symptoms**: API returns 400 with message about connection not being found.

**Solutions**:
1. Verify that you have set up an "email" connection for passwordless in Auth0 Dashboard
2. Make sure the connection is enabled for your application

### Rate Limiting Errors (429)

**Symptoms**: API returns 429 "Too Many Requests" error.

**Solutions**:
1. Implement exponential backoff in your code
2. Add the `auth0-forwarded-for` header with the end user's IP when calling from a server

## Verifying Configuration from Auth0 Dashboard

1. Go to **Applications > APIs** and verify that your API is properly configured
2. Check the **Test** tab in your application settings to see example code
3. Use the "Try" button in the Auth0 Dashboard to test your configuration

## References

- [Auth0 Passwordless Documentation](https://auth0.com/docs/authenticate/passwordless)
- [Passwordless API Endpoints](https://auth0.com/docs/authenticate/passwordless/implement-login/embedded-login/relevant-api-endpoints)
- [Auth0 Rate Limiting Documentation](https://auth0.com/docs/troubleshoot/customer-support/operational-policies/rate-limit-policy)
