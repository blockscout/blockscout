_[GitHub keywords to close any associated issues](https://blog.github.com/2013-05-14-closing-issues-via-pull-requests/)_

### Description

 _A few sentences describing the overall effects and goals of the pull request's commits._
 _What is the current behavior, and what is the updated/expected behavior with this PR?_
 
 ### Other changes

 _Describe any minor or "drive-by" changes here._

### Tested

 _An explanation of how the changes were tested or an explanation as to why they don't need to be._
 _Add any artifacts (links, screenshots) you can include to increase the reviewers' confidence in the change._

### Issues

 - Relates to #[issue number here]
 - Fixes #[issue number here]

 ### Backwards compatibility

 _Brief explanation of why these changes are/are not backwards compatible._

### Checklist

<!--
  Ideally a PR has all of the checkmarks set.

  If something in this list is irrelevant to your PR, you should still set this
  checkmark indicating that you are sure it is dealt with (be that by irrelevance).

  If you don't set a checkmark (e. g. don't add a test for new functionality),
  please justify why.
-->

  - [ ] If I added new functionality, I added tests covering it.
  - [ ] If I fixed a bug, I added a regression test to prevent the bug from silently reappearing again.
  - [ ] I added code comments for anything non trivial.
  - [ ] I added documentation for my changes.
  - [ ] If I added/changed/removed ENV var, I submitted a PR to https://github.com/celo-org/monorepo to update the list and default values of env vars.
  - [ ] If I add new indices into DB, I checked, that they are not redundant with PGHero or other tools.
