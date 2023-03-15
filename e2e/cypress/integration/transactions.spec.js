/// <reference types='Cypress' />

import * as BasePage from "../pages/BasePage";
import * as TransactionsPage from "../pages/TransactionsPage";

describe("Transactions", () => {
  describe("Base page transactions", () => {
    before(() => {
      cy.intercept("GET", "/recent-transactions").as("transactions");
      cy.visit("/");
    });

    it("should display transactions", function () {
      BasePage.verifyTransactionsCount();
      cy.wait("@transactions").then(
        ({
          response: {
            body: { transactions },
          },
        }) => {
          BasePage.verifyTransactions(transactions);
        }
      );
    });
  });

  describe("Transactions page transactions", () => {
    const transactionsSearchParam =
      "block_number=1115000&index=0&items_count=200";

    before(() => {
      cy.visit(`/txs?${transactionsSearchParam}`);
    });

    it("should display historic transactions", function () {
      TransactionsPage.allPageTransactions().snapshot();
    });
  });
});
