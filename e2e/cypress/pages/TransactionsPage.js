/// <reference types='Cypress' />

export const allPageTransactions = () =>
  cy.get("[data-test='transaction_hash_link']");
