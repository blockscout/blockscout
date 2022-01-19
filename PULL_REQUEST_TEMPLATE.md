*[GitHub keywords to close any associated issues](https://blog.github.com/2013-05-14-closing-issues-via-pull-requests/)*

## Motivation

*Why we should merge these changes.  If using GitHub keywords to close [issues](https://github.com/poanetwork/blockscout/issues), this is optional as the motivation can be read on the issue page.*

## Changelog

### Enhancements
*Things you added that don't break anything.  Regression tests for Bug Fixes count as Enhancements.*

### Bug Fixes
*Things you changed that fix bugs.  If a fixes a bug, but in so doing adds a new requirement, removes code, or requires a database reset and reindex, the breaking part of the change should be added to Incompatible Changes below also.*

### Incompatible Changes
*Things you broke while doing Enhancements and Bug Fixes.  Breaking changes include (1) adding new requirements and (2) removing code.  Renaming counts as (2) because a rename is a removal followed by an add.*

## Upgrading

*If you have any Incompatible Changes in the above Changelog, outline how users of prior versions can upgrade once this PR lands or when reviewers are testing locally.  A common upgrading step is "Database reset and re-index required".*

## Checklist for your Pull Request (PR)

  - [ ] I added an entry to `CHANGELOG.md` with this PR
  - [ ] If I added new functionality, I added tests covering it.
  - [ ] If I fixed a bug, I added a regression test to prevent the bug from silently reappearing again.
  - [ ] I checked whether I should update the docs and did so by submitting a PR to https://github.com/blockscout/docs
  - [ ] If I added/changed/removed ENV var, I submitted a PR to https://github.com/blockscout/docs to update the list of env vars at https://github.com/blockscout/docs/blob/master/for-developers/information-and-settings/env-variables.md and I updated the version to `master` in the Version column. Changes will be reflected in this table: https://docs.blockscout.com/for-developers/information-and-settings/env-variables. 
  - [ ] If I add new indices into DB, I checked, that they are not redundant with PGHero or other tools
