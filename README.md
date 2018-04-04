# POA Explorer [![CircleCI](https://circleci.com/gh/poanetwork/poa-explorer.svg?style=svg&circle-token=f8823a3d0090407c11f87028c73015a331dbf604)](https://circleci.com/gh/poanetwork/poa-explorer)

This is a tool for inspecting and analyzing the POA Network blockchain.


## Machine Requirements

* Erlang/OTP 20.2+
* Elixir 1.5+
* Postgres 10.0


## Required Accounts

* Heroku for deployment
* Github for code storage


## Setup Instructions

### Development

To get POA Explorer up and running locally:

  * Set up some default configuration with: `$ cp apps/explorer/config/dev.secret.exs.example apps/explorer/config/dev.secret.exs`
  * Set up some default configuration with: `$ cp apps/explorer_web/config/dev.secret.exs.example apps/explorer_web/config/dev.secret.exs`
  * Install dependencies with `$ mix do deps.get, local.rebar, deps.compile, compile`
  * Create and migrate your database with `$ mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `$ cd apps/explorer_web/assets && npm install && cd -`
  * Start Phoenix with `$ iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

You can also run IEx (Interactive Elixir): `$ iex -S mix phx.server`

### CircleCI Updates

Configure your local CCMenu with the following url: [`https://circleci.com/gh/poanetwork/poa-explorer.cc.xml?circle-token=f8823a3d0090407c11f87028c73015a331dbf604`](https://circleci.com/gh/poanetwork/poa-explorer.cc.xml?circle-token=f8823a3d0090407c11f87028c73015a331dbf604)

### Testing

  * Build the assets: `$ cd apps/explorer_web/assets && yarn build && cd -`
  * Format the Elixir code: `$ mix format`
  * Run the test suite: `$ mix test`
  * Lint the Elixir code: `$ mix credo --strict`
  * Run the dialyzer: `mix dialyzer --halt-exit-status`
  * Check the Elixir code for vulnerabilities: `$ mix sobelow --config`
  * Lint the JavaScript code: `$ cd apps/explorer_web/assets && yarn eslint && cd -`


## Internationalization

The app is currently internationalized. It is only localized to U.S. English.

To translate new strings, run `$ cd apps/explorer_web; mix gettext.extract --merge` and edit the new strings in `apps/explorer_web/priv/gettext/en/LC_MESSAGES/default.po`.

## Contributing

1. Fork it ( https://github.com/poanetwork/poa-explorer/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Write tests that cover your work
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create a new Pull Request
