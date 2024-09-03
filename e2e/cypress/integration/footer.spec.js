/// <reference types='Cypress' />

import * as Footer from "../page-objects/Footer";

describe("Footer", () => {
  beforeEach(() => {
    cy.visit("/");
  });

  it("should only contain Genesis logo", function () {
    Footer.footer().snapshot();
  });
});
