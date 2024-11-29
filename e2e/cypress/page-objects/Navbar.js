/// <reference types='Cypress' />

export const navbar = () => cy.get("#top-navbar");
export const logo = () => cy.get("[data-test='header_logo']");

export const logoVerify = () =>
  logo().then((el) => {
    const link = el[0].href;
    const baseUrl = Cypress.config().baseUrl;
    const image = el[0].children[0];

    expect(link).eq(baseUrl);
    cy.log(`verified link ${baseUrl}`);
    expect(image.src).eq(`${baseUrl}images/genesis-black.svg`);
    cy.log(`verified logo path ${image.src}`);
  });

export const blocksDropdown = () => cy.get("#navbarBlocksDropdown");
export const transactionsDropdown = () => cy.get("#navbarTransactionsDropdown");
export const accounts = () => cy.contains("a", "Accounts");
export const tokens = () => cy.contains("a", "Tokens");
export const apis = () => cy.get("#navbarAPIsDropdown");
export const apps = () => cy.get("#navbarAppsDropdown");
export const searchBox = () => cy.findByLabelText("Search");
