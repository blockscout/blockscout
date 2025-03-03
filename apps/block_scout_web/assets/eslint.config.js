// eslint.config.js
const eslint = require("@eslint/js");
const globals = require('globals');
module.exports = [
  eslint.configs.recommended,
  {
      // your configuration here
      languageOptions: {
        globals: {
            ...globals.browser,
            ...globals.node,
        }
      },
      rules: {
        'no-unused-vars': ['error', {
          args: 'none',
          caughtErrors: 'none',
          ignoreRestSiblings: true,
          vars: 'all'
        }],
      }
  }
];