defmodule Explorer.Accounts.Notify.EmailTest do
  use ExUnit.Case

  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Explorer.Chain.Hash
  alias Explorer.Chain.Transaction

  alias Explorer.Accounts.{
    Identity,
    Watchlist,
    WatchlistAddress,
    WatchlistNotification
  }

  import Explorer.Chain,
    only: [
      string_to_address_hash: 1,
      string_to_transaction_hash: 1
    ]

  import Explorer.Accounts.Notifier.Email,
    only: [compose: 2]

  setup do
    host = Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host]
    path = Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:path]

    Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint, url: [host: "localhost", path: "/"])

    Application.put_env(:explorer, Explorer.Accounts,
      sendgrid: [
        sender: "noreply@blockscout.com",
        template: "d-666"
      ]
    )

    :ok

    on_exit(fn ->
      Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint, url: [host: host, path: path])
    end)
  end

  describe "composing email" do
    test "compose_email" do
      {:ok, tx_hash} = string_to_transaction_hash("0x5d5ff210261f1b2d6e4af22ea494f428f9997d4ab614a629d4f1390004b3e80d")
      transaction_hash = %Transaction{hash: tx_hash}

      {:ok, from_hash} = string_to_address_hash("0x092D537737E767Dae48c28aE509f34094496f030")
      from_address_hash = %Address{hash: from_hash}

      {:ok, to_hash} = string_to_address_hash("0xE1F4dd38f00B0D8D4d2b4B5010bE53F2A0b934E5")
      to_address = %Address{hash: to_hash}

      identity = %Identity{
        uid: "foo|bar",
        name: "John Snow",
        email: "john@blockscout.com"
      }

      watchlist = %Watchlist{identity: identity}

      watchlist_address = %WatchlistAddress{
        name: "wallet",
        watchlist: watchlist,
        address: to_address,
        address_hash: to_hash,
        watch_coin_input: true,
        watch_coin_output: true,
        notify_email: true
      }

      watchlist_notification = %WatchlistNotification{
        watchlist_address: watchlist_address,
        transaction_hash: tx_hash,
        from_address_hash: from_hash,
        to_address_hash: to_hash,
        direction: "incoming",
        method: "transfer",
        block_number: 24_121_177,
        amount: Decimal.new(1),
        tx_fee: Decimal.new(210_000),
        name: "wallet",
        type: "COIN"
      }

      assert compose(watchlist_notification, watchlist_address) ==
               %Bamboo.Email{
                 assigns: %{},
                 attachments: [],
                 bcc: nil,
                 blocked: false,
                 cc: nil,
                 from: "noreply@blockscout.com",
                 headers: %{},
                 html_body: nil,
                 private: %{
                   send_grid_template: %{
                     dynamic_template_data: %{
                       "address_hash" => "0xe1f4dd38f00b0d8d4d2b4b5010be53f2a0b934e5",
                       "address_name" => "wallet",
                       "address_url" => "https://localhost//address/0xe1f4dd38f00b0d8d4d2b4b5010be53f2a0b934e5",
                       "amount" => Decimal.new(1),
                       "block_number" => 24_121_177,
                       "block_url" => "https://localhost/block/24121177",
                       "direction" => "received at",
                       "from_address_hash" => "0x092d537737e767dae48c28ae509f34094496f030",
                       "from_url" => "https://localhost//address/0x092d537737e767dae48c28ae509f34094496f030",
                       "method" => "transfer",
                       "name" => "wallet",
                       "to_address_hash" => "0xe1f4dd38f00b0d8d4d2b4b5010be53f2a0b934e5",
                       "to_url" => "https://localhost//address/0xe1f4dd38f00b0d8d4d2b4b5010be53f2a0b934e5",
                       "transaction_hash" => "0x5d5ff210261f1b2d6e4af22ea494f428f9997d4ab614a629d4f1390004b3e80d",
                       "transaction_url" =>
                         "https://localhost//tx/0x5d5ff210261f1b2d6e4af22ea494f428f9997d4ab614a629d4f1390004b3e80d",
                       "tx_fee" => Decimal.new(210_000),
                       "username" => "John Snow"
                     },
                     template_id: "d-666"
                   }
                 },
                 subject: nil,
                 text_body: nil,
                 to: "john@blockscout.com"
               }
    end
  end
end
