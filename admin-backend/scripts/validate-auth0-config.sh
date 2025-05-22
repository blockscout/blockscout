#!/bin/bash

# Auth0 Configuration Validation Script
# This script checks if your Auth0 environment variables are correctly set up

echo "🔐 Validating Auth0 Configuration..."
echo "-----------------------------------"

# Check if environment variables are set
check_env_var() {
  if [ -z "${!1}" ]; then
    echo "❌ $1 is not set in your environment"
    return 1
  else
    echo "✅ $1 is set: ${!1}"
    return 0
  fi
}

# Get the parent directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"

# Source the .env file if it exists
if [ -f "$BACKEND_DIR/.env" ]; then
  echo "📄 Loading environment variables from $BACKEND_DIR/.env file"
  set -a
  source "$BACKEND_DIR/.env"
  set +a
else
  echo "⚠️ No .env file found at $BACKEND_DIR/.env, checking system environment variables"
fi

# Check required Auth0 variables
auth0_vars=(
  "AUTH0_DOMAIN"
  "AUTH0_CLIENT_ID"
  "AUTH0_CLIENT_SECRET"
  "AUTH0_AUDIENCE"
  "AUTH0_CALLBACK_URL"
)

all_vars_set=true

for var in "${auth0_vars[@]}"; do
  if ! check_env_var "$var"; then
    all_vars_set=false
  fi
done

# Verify other critical configs
echo "-----------------------------------"
echo "ℹ️ Auth0 Configuration Summary:"
echo "• Domain: $AUTH0_DOMAIN"
echo "• Client ID: ${AUTH0_CLIENT_ID:0:5}..."
echo "• Client Secret: ${AUTH0_CLIENT_SECRET:0:5}... (masked for security)"
echo "• Callback URL: $AUTH0_CALLBACK_URL"
echo ""
echo "ℹ️ Important Configuration Reminders:"
echo "1. Make sure to enable the Passwordless OTP grant at Auth0 Dashboard > Applications > Applications"
echo "   in your application's settings under Advanced Settings > Grant Types."
echo "2. Verify that you have set up an 'email' connection for passwordless authentication in the Auth0 Dashboard."
echo "3. Check that your application's Allowed Callback URLs include: ${AUTH0_CALLBACK_URL}"
echo ""
echo "🔧 If you're experiencing 'Client authentication is required' errors, verify:"
echo "  • Passwordless OTP grant is enabled"
echo "  • Client ID and Client Secret are correct" 
echo "  • Email connection is set up properly for passwordless"
echo "-----------------------------------"

# Try to validate the Auth0 configuration by making a test API call
if [[ -n "$AUTH0_DOMAIN" && -n "$AUTH0_CLIENT_ID" && -n "$AUTH0_CLIENT_SECRET" ]]; then
  echo "🔍 Testing Auth0 connection..."
  
  # Use curl to check the passwordless configuration
  response=$(curl -s -X POST "https://${AUTH0_DOMAIN}/passwordless/start" \
    -H "Content-Type: application/json" \
    -d '{
      "client_id": "'${AUTH0_CLIENT_ID}'",
      "client_secret": "'${AUTH0_CLIENT_SECRET}'",
      "connection": "email",
      "email": "test@example.com",
      "send": "link",
      "authParams": {
        "scope": "openid profile email",
        "redirect_uri": "'${AUTH0_CALLBACK_URL}'"
      }
    }')
  
  # Check if error is present in the response
  if echo "$response" | grep -q "error"; then
    echo "❌ Auth0 test failed with response: $response"
    
    # Check for specific error types and provide guidance
    if echo "$response" | grep -q "unauthorized_client"; then
      echo "⚠️ Passwordless OTP grant may not be enabled or client credentials are incorrect."
    fi
    
    if echo "$response" | grep -q "connection"; then
      echo "⚠️ 'email' connection may not be set up properly for passwordless authentication."
    fi
  else
    echo "✅ Auth0 passwordless configuration test passed!"
  fi
fi
echo ""
echo "🔧 Verifying other critical configuration..."
if [ -f "$BACKEND_DIR/package.json" ]; then
  echo "✅ package.json exists"
else
  echo "❌ package.json not found at $BACKEND_DIR/package.json"
  all_vars_set=false
fi

if [ -d "$BACKEND_DIR/node_modules" ]; then
  echo "✅ node_modules directory exists"
else
  echo "⚠️ node_modules directory not found. Have you run 'npm install'?"
fi

# Explain next steps based on validation results
echo ""
if [ "$all_vars_set" = true ]; then
  echo "✅ Auth0 configuration looks good!"
  echo ""
  echo "Next steps:"
  echo "1. Make sure your Auth0 application is configured with:"
  echo "   - Allowed Callback URLs: $AUTH0_CALLBACK_URL"
  echo "   - Allowed Logout URLs: $AUTH0_LOGOUT_URL"
  echo "   - Allowed Web Origins: ${AUTH0_CALLBACK_URL%/*}"
  echo ""
  echo "2. Enable the Email Passwordless Connection in Auth0"
  echo "   - Go to Auth0 Dashboard -> Authentication -> Passwordless"
  echo "   - Enable Email with Magic Link"
  echo ""
  echo "3. Start your backend and frontend applications"
  echo "   - Backend: npm start"
  echo "   - Frontend: npm run dev"
  echo ""
  echo "   Or use Docker with our helper script:"
  echo "   - ./admin-panel.sh start"
else
  echo "❌ Auth0 configuration is incomplete."
  echo ""
  echo "Please update your .env file with the missing values."
  echo "You can get these values from your Auth0 dashboard at: https://manage.auth0.com/"
  echo ""
  echo "For help setting up Auth0, refer to the README.md file."
fi
