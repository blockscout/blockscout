module.exports = {
  env: {
    node: true,
    es6: true,
    jest: true
  },
  extends: 'eslint:recommended',
  parserOptions: {
    ecmaVersion: 2020
  },
  rules: {
    'no-console': process.env.NODE_ENV === 'production' ? 'warn' : 'off',
    'no-debugger': process.env.NODE_ENV === 'production' ? 'error' : 'off',
    'indent': ['error', 2],
    'semi': ['error', 'always'],
    'quotes': ['error', 'single']
  }
};
