// Script per testare l'intero flusso di autenticazione passwordless
require('dotenv').config();
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));
const authConfig = require('./config/auth0');
const readline = require('readline');

// Crea interfaccia per input da console
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Funzione per richiedere input all'utente
const questionAsync = (question) => {
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      resolve(answer);
    });
  });
};

// Test della funzionalità completa di passwordless
async function testPasswordlessFlow() {
  try {
    console.log('Auth0 Config:', {
      domain: authConfig.domain,
      clientId: authConfig.clientId.substring(0, 5) + '...',
      clientSecret: authConfig.clientSecret ? 'Set (masked)' : 'Not set',
      callbackUrl: authConfig.callbackUrl,
      connection: authConfig.passwordlessConnection
    });

    // Step 1: Email input
    const email = await questionAsync('\nInserisci la tua email: ');
    
    console.log('\n1. Invio del codice di verifica all\'email...');
    console.log(`Using Auth0 domain: ${authConfig.domain}`);
    
    const startResponse = await fetch(`https://${authConfig.domain}/passwordless/start`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        client_id: authConfig.clientId,
        client_secret: authConfig.clientSecret,
        connection: authConfig.passwordlessConnection || 'email',
        email: email,
        send: 'code',
        authParams: {
          scope: 'openid',
        }
      })
    });
    
    if (!startResponse.ok) {
      const errorData = await startResponse.json();
      console.error(`❌ Error: ${startResponse.status} ${startResponse.statusText}`);
      console.error('Error details:', errorData);
      
      // Fornisci consigli di risoluzione dei problemi
      if (startResponse.status === 403 && errorData.error === 'unauthorized_client') {
        console.log('\n🔧 Troubleshooting:');
        console.log('1. Verifica che Passwordless OTP grant sia abilitato in Auth0 Dashboard > Applications > Advanced Settings > Grant Types');
        console.log('2. Controlla che client_id e client_secret siano corretti');
        console.log('3. Assicurati che una connessione "email" sia configurata per passwordless in Auth0 Dashboard');
      }
      rl.close();
      return;
    }
    
    const startData = await startResponse.json();
    console.log('✅ Codice inviato con successo!');
    console.log('Response:', startData);
    
    // Step 2: Verifica del codice OTP
    const otp = await questionAsync('\nInserisci il codice di verifica ricevuto via email: ');
    
    console.log('\n2. Verifica del codice OTP...');
    
    const verifyResponse = await fetch(`https://${authConfig.domain}/oauth/token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        grant_type: 'http://auth0.com/oauth/grant-type/passwordless/otp',
        client_id: authConfig.clientId,
        client_secret: authConfig.clientSecret,
        username: email,
        otp: otp,
        realm: authConfig.passwordlessConnection || 'email',
        scope: 'openid profile email'
      })
    });
    
    if (!verifyResponse.ok) {
      const errorData = await verifyResponse.json();
      console.error(`❌ Error: ${verifyResponse.status} ${verifyResponse.statusText}`);
      console.error('Error details:', errorData);
      rl.close();
      return;
    }
    
    const tokenData = await verifyResponse.json();
    console.log('✅ Autenticazione riuscita!');
    console.log('Tokens:', {
      access_token: tokenData.access_token ? tokenData.access_token.substring(0, 10) + '...' : 'Not provided',
      id_token: tokenData.id_token ? tokenData.id_token.substring(0, 10) + '...' : 'Not provided',
      token_type: tokenData.token_type,
      expires_in: tokenData.expires_in
    });
    
    // Step 3: Ottieni il profilo utente
    if (tokenData.access_token) {
      console.log('\n3. Recupero del profilo utente...');
      
      const userResponse = await fetch(`https://${authConfig.domain}/userinfo`, {
        headers: {
          Authorization: `Bearer ${tokenData.access_token}`
        }
      });
      
      if (!userResponse.ok) {
        console.error(`❌ Error getting user profile: ${userResponse.status} ${userResponse.statusText}`);
      } else {
        const userData = await userResponse.json();
        console.log('✅ Profilo utente recuperato!');
        console.log('User profile:', userData);
      }
    }
    
  } catch (error) {
    console.error('❌ Unexpected error:', error);
  } finally {
    rl.close();
  }
}

// Esegui il test
testPasswordlessFlow().catch(err => {
  console.error('Unhandled error:', err);
  rl.close();
  process.exit(1);
});
