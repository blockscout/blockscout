# BlockScout Web

BlockScoutWeb is the API and presentation layer of BlockScout built on the Phoenix framework. It exposes RESTful and GraphQL APIs for accessing blockchain data. It directs HTTP requests through Phoenix routers to controllers that manage resources like addresses, transactions, blocks, and tokens. It formats responses as JSON via view modules. It provides real-time updates on new blocks, transactions, and exchange rates using Phoenix Channels. It supports smart contract verification through multiple methods including integration with Sourcify. Custom plugs add functionalities such as rate limiting, API version checks, and logging. Configuration is retrieved from the application environment. It manages errors through fallback controllers.

## Machine Requirements

* Erlang/OTP 21+
* Elixir 1.9+
* Postgres 10.3

## Required Accounts

* Github for code storage

## Setup Instructions

### Development

To get BlockScout Web interface up and running locally:

* Setup `../explorer`
* Install Node.js dependencies with `$ cd assets && npm install && cd ..`
* Start Phoenix with `$ mix phx.server` (This can be run from this directory or the project root: the project root is recommended.)

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

You can also run IEx (Interactive Elixir): `$ iex -S mix phx.server` (This can be run from this directory or the project root: the project root is recommended.)

### Testing

* Build the assets: `cd assets && npm run build`
* Format the Elixir code: `mix format`
* Lint the Elixir code: `mix credo --strict`
* Run the dialyzer: `mix dialyzer --halt-exit-status`
* Check the Elixir code for vulnerabilities: `mix sobelow --config`
* Update translation templates and translations and check there are no uncommitted changes: `mix gettext.extract --merge`
* Lint the JavaScript code: `cd assets && npm run eslint`

## Internationalization

The app is currently internationalized. It is only localized to U.S. English.

To translate new strings, run `$ mix gettext.extract --merge` and edit the new strings in `priv/gettext/en/LC_MESSAGES/default.po`.
