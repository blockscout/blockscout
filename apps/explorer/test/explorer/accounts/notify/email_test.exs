# defmodule Explorer.Accounts.Notify.EmailTest do
#   use ExUnit.Case

#   alias Explorer.Chain
#   alias Explorer.Chain.Address
#   alias Explorer.Chain.Hash
#   alias Explorer.Chain.Transaction

#   alias Explorer.Accounts.{
#     Identity,
#     Watchlist,
#     WatchlistAddress,
#     WatchlistNotification
#   }

#   import Explorer.Chain,
#     only: [
#       string_to_address_hash: 1,
#       string_to_transaction_hash: 1
#     ]

#   def to_hash(hash_string) do
#     string_to_address_hash(address_hash_string)
#   end

#   @identity %Identity{
#     uid: "foo|bar",
#     name: "John Snow",
#     email: "john@blockscout.com"
#   }

#   @watchlist %Watchlist{identity: @identity}

#   @transaction_hash %Transaction{
#     hash: string_to_transaction_hash("0x5d5ff210261f1b2d6e4af22ea494f428f9997d4ab614a629d4f1390004b3e80d")
#   }

#   @from_address %Address{
#     hash: string_to_address_hash("0x092D537737E767Dae48c28aE509f34094496f030")
#   }

#   @to_address %Address{
#     hash: string_to_address_hash("0xE1F4dd38f00B0D8D4d2b4B5010bE53F2A0b934E5")
#   }

#   @watchlist_address %WatchlistAddress{
#     name: "wallet",
#     watchlist: @watchlist,
#     address: @to_address,
#     watch_coin_input: true,
#     watch_coin_output: true,
#     notify_email: true
#   }

# @watchlist_notification %WatchlistNotification{
#   watchlist_address: @watchlist_address,
#   transaction_hash: @transaction_hash,
#   from_address_hash: summary.from_address_hash,
#   to_address_hash: summary.to_address_hash,
#   direction: to_string(direction),
#   method: summary.method,
#   block_number: summary.block_number,
#   amount: summary.amount,
#   tx_fee: summary.tx_fee,
#   name: summary.name,
#   type: summary.type
# }

# describe "composing email" do
#   test "compose_email" do
#     assert Email.compose_email(@watchlist_notification) = 
#     %Bamboo.Email{
# assigns: %{},
# attachments: [],
# bcc: nil,
# blocked: false,
# cc: nil,
# from: "ulyana@blockscout.com",
# headers: %{},
# html_body: nil,
# private: %{
#   send_grid_template: %{
#     dynamic_template_data: %{
#       "address_hash" => "0x09FC0E491D6CAD3D018BB0FC5B3CD4E93D40EB12",
#       "address_name" => "wallet",
#       "address_url" => "https://barabulia//address/0x09fc0e491d6cad3d018bb0fc5b3cd4e93d40eb12",
#       "amount" => Decimal.new(1),
#       "block_number" => 24121177,
#       "block_url" => "https://barabulia//tx/0x0b5fc48aba47006f69f6ede5eafa32837951f317aab6896ed58bcd05cc5159e5",
#       "direction" => "transfer",
#       "from_address_hash" => "0xDD0BB0E2A1594240FED0C2F2C17C1E9AB4F87126",
#       "from_url" => "https://barabulia//address/0xdd0bb0e2a1594240fed0c2f2c17c1e9ab4f87126",
#       "method" => "transfer",
#       "name" => "POA",
#       "to_address_hash" => "0x09FC0E491D6CAD3D018BB0FC5B3CD4E93D40EB12",
#       "to_url" => "https://barabulia//address/0x09fc0e491d6cad3d018bb0fc5b3cd4e93d40eb12",
#       "transaction_hash" => "0x0B5FC48ABA47006F69F6EDE5EAFA32837951F317AAB6896ED58BCD05CC5159E5",
#       "transaction_url" => "https://barabulia//tx/0x0b5fc48aba47006f69f6ede5eafa32837951f317aab6896ed58bcd05cc5159e5",
#       "tx_fee" => Decimal.new(210000),
#       "username" => "Oleg Sovetnik"
#     },
#     template_id: "d-7ab86397e5bb4f0e94e285879a42be64"
#   }
# },
# subject: nil,
# text_body: nil,
# to: "sovetnik@oblaka.biz"
# }
#   end
# end
# end
