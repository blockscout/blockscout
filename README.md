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

  * Set up some default configuration with: `$ cp config/dev.secrets.esx.example config/dev.secrets.esx`
  * Install dependencies with `$ mix do deps.get, local.rebar, deps.compile, compile`
  * Create and migrate your database with `$ mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `$ cd assets && npm install && cd ..`
  * Start Phoenix with `$ mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

You can also run IEx (Interactive Elixir): `$ iex -S mix phx.server`

### CircleCI Updates

Configure your local CCMenu with the following url: [`https://circleci.com/gh/poanetwork/poa-explorer.cc.xml?circle-token=f8823a3d0090407c11f87028c73015a331dbf604`](https://circleci.com/gh/poanetwork/poa-explorer.cc.xml?circle-token=f8823a3d0090407c11f87028c73015a331dbf604)

### Testing

To run the test suite: `$ mix test`

To ensure your Elixir code is properly formatted: `$ mix credo --strict`
To ensure your ES code is properly formatted: `$ cd assets && npm run eslint`


## Internationalization

The app is currently internationalized. It is only localized to U.S. English.

To translate new strings, run `$ mix gettext.extract --merge` and edit the new strings in `priv/gettext/en/LC_MESSAGES/default.po`.

## Contributing

1. Fork it ( https://github.com/poanetwork/poa-explorer/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Write tests that cover your work
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create a new Pull Request
