<!--internationalization.md -->


## Internationalization

The app is currently internationalized. It is only localized to U.S. English. To translate new strings.

1. To setup translation file.
`cd apps/block_scout_web; mix gettext.extract --merge; cd -`
2. To edit the new strings, go to `apps/block_scout_web/priv/gettext/en/LC_MESSAGES/default.po`.