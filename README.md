# POA Explorer [![CircleCI](https://circleci.com/gh/poanetwork/poa-explorer.svg?style=svg&circle-token=f8823a3d0090407c11f87028c73015a331dbf604)](https://circleci.com/gh/poanetwork/poa-explorer)

This is a tool for inspecting and analyzing the POA Network blockchain.


## Machine Requirements

* Elixir 1.3
* Postgres 10.0


## Required Accounts

* Heroku for deployment
* Github for code storage


## Setup Instructions

### Development

To get POA Explorer up and running locally:

  * Install dependencies with `$ mix deps.get`
  * Create and migrate your database with `$ mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `$ cd assets && npm install && cd ..`
  * Start Phoenix with `$ mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

You can also run IEx (Interactive Elixir): `$ iex -S mix phx.server`


### Testing

To run the test suite: `$ mix test`


## Contributing

1. Fork it ( https://github.com/poanetwork/explorer/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Write tests that cover your work
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create a new Pull Request
