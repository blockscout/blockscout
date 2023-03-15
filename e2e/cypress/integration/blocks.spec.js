/// <reference types='Cypress' />

import * as Blocks from "../page-objects/Blocks";

describe("Blocks", () => {
  describe("Blocks page", () => {
    before(() => {});

    it("should be generatating new blocks - blocks page", function () {
      let oldBlockId;
      let newBlockId;

      cy.visit("/blocks");

      Blocks.firstBlockId().then((blockId) => {
        oldBlockId = blockId;
      });

      // eslint-disable-next-line cypress/no-unnecessary-waiting
      cy.wait(11000);

      Blocks.firstBlockId().then((blockId) => {
        newBlockId = blockId;
        expect(oldBlockId).to.not.eq(newBlockId);
      });
    });

    it("should display historic blocks", function () {
      cy.visit("/blocks?block_number=100&block_type=Block&items_count=200");

      Blocks.allBlocksOnPage().snapshot();
    });
  });

  describe("Base page", () => {
    before(() => {
      cy.visit("/");
    });

    it("should be generatating new blocks - base page", function () {
      let oldBlockId;
      let newBlockId;

      Blocks.firstBlockId().then((blockId) => {
        oldBlockId = blockId;
      });

      // eslint-disable-next-line cypress/no-unnecessary-waiting
      cy.wait(11000);

      Blocks.firstBlockId().then((blockId) => {
        newBlockId = blockId;
        expect(oldBlockId).to.not.eq(newBlockId);
      });
    });
  });
});
