# BlockScout Web

This is a tool for inspecting and analyzing the POA Network blockchain from a web browser.

## Machine Requirements

* Erlang/OTP 20.2+
* Elixir 1.5+
* Postgres 10.0


## Required Accounts

* Github for code storage


## Setup Instructions

### Development

To get BlockScout Web interface up and running locally:

  * Setup `../explorer`
  * Set up some default configuration with: `$ cp config/dev.secret.exs.example config/dev.secret.exs`
  * Install Node.js dependencies with `$ cd assets && npm install && cd ..`
  * Start Phoenix with `$ mix phx.server` (This can be run from this directory or the project root: the project root is recommended.)

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

You can also run IEx (Interactive Elixir): `$ iex -S mix phx.server` (This can be run from this directory or the project root: the project root is recommended.)

### Testing

  * Build the assets: `cd assets && npm run build`
  * Format the Elixir code: `mix format`
  * Run the test suite with coverage: `mix coveralls.html`
  * Lint the Elixir code: `mix credo --strict`
  * Run the dialyzer: `mix dialyzer --halt-exit-status`
  * Check the Elixir code for vulnerabilities: `mix sobelow --config`
  * Update translations templates and translations and check there are no uncommitted changes: `mix gettext.extract --merge`
  * Lint the JavaScript code: `cd assets && npm run eslint`


## Internationalization

The app is currently internationalized. It is only localized to U.S. English.

To translate new strings, run `$ mix gettext.extract --merge` and edit the new strings in `priv/gettext/en/LC_MESSAGES/default.po`.
