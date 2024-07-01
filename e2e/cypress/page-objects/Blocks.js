/// <reference types='Cypress' />

export const firstBlockId = () =>
  cy.get('[data-selector="block-number"]').eq(0).invoke("text");

export const allBlocksOnPage = () => cy.get("[data-items]");
