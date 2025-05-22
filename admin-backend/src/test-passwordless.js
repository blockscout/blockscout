// filepath: /Users/lucasimonetti/uomi-explorer/admin-backend/src/test-passwordless.js
require('dotenv').config();
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));
const authConfig = require('./config/auth0');

// Test function
async function testPasswordlessEmail() {
  try {
    console.log('Auth0 Config:', {
      domain: authConfig.domain,
      clientId: authConfig.clientId.substring(0, 5) + '...',
      clientSecret: authConfig.clientSecret ? 'Set (masked)' : 'Not set',
      callbackUrl: authConfig.callbackUrl,
      connection: authConfig.passwordlessConnection
    });

  console.log('\n1. Testing passwordless email with direct API call...');
    console.log(`Using Auth0 domain: ${authConfig.domain}`);
    
    const response = await fetch(`https://${authConfig.domain}/passwordless/start`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        client_id: authConfig.clientId,
        client_secret: authConfig.clientSecret,
        connection: authConfig.passwordlessConnection || 'email',
        email: 'lucasimonetti21@gmail.com',
        send: 'code',
        authParams: {
          scope: 'openid',
        }
      })
    });
    
    if (!response.ok) {
      const errorData = await response.json();
      console.error(`❌ Error: ${response.status} ${response.statusText}`);
      console.error('Error details:', errorData);
      
      // Provide troubleshooting guidance
      if (response.status === 403 && errorData.error === 'unauthorized_client') {
        console.log('\n🔧 Troubleshooting:');
        console.log('1. Verify that Passwordless OTP grant is enabled in Auth0 Dashboard > Applications > Advanced Settings > Grant Types');
        console.log('2. Check that your client_id and client_secret are correct');
        console.log('3. Ensure that an "email" connection is set up for passwordless in Auth0 Dashboard');
      }
    } else {
      const data = await response.json();
      console.log('✅ Email sent successfully!');
      console.log('Response:', data);
    }
    
  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

// Run the test
testPasswordlessEmail().catch(err => {
  console.error('Unhandled error:', err);
  process.exit(1);
});
