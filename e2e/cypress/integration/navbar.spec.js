/// <reference types='Cypress' />

import * as Navbar from "../page-objects/Navbar";

describe("Navbar", () => {
  beforeEach(() => {
    cy.intercept("GET", "/recent-transactions").as("transactions");
    cy.visit("/");
  });

  it("should display navbar features", function () {
    Navbar.logoVerify();
  });
});
