/// <reference types='Cypress' />

import Decimal from "decimal.js-light";

export const transactionsCount = () =>
  cy.get("[data-selector = 'transaction-count']").invoke("text");

export const transactions = () => cy.get('[data-test="transaction_hash_link"]');
export const verifyTransactionsCount = () =>
  transactionsCount().then((text) => {
    expect(new Decimal(text.replace(",", ".")).toNumber()).to.be.above(0);
  });

export const verifyTransactions = (transactions) =>
  transactions.map((transaction, index) =>
    cy
      .get('[data-test="transaction_hash_link"]')
      .eq(index)
      .should("have.attr", "href", `/tx/${transaction.transaction_hash}`)
      .and("have.text", transaction.transaction_hash)
      .parent()
      .should("include.text", "GEN")
  );
