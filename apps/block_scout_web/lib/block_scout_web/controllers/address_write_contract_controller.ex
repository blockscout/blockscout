# credo:disable-for-this-file
#
# When moving the calls to ajax, this controller became very similar to the
# `address_contract_controller`, but both are necessary until we are able to
# address a better way to organize the controllers.
#
# So, for now, I'm adding this comment to disable the credo check for this file.
defmodule BlockScoutWeb.AddressWriteContractController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]

  alias BlockScoutWeb.AccessHelpers
  alias BlockScoutWeb.AddressView
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand

  def index(conn, %{"address_id" => address_hash_string} = params) do
    address_options = [
      necessity_by_association: %{
        :contracts_creation_internal_transaction => :optional,
        :names => :optional,
        :smart_contract => :optional,
        :token => :optional,
        :contracts_creation_transaction => :optional
      }
    ]

    custom_abi? = AddressView.has_address_custom_abi_with_write_functions?(conn, address_hash_string)

    base_params = [
      type: :regular,
      action: :write,
      custom_abi: custom_abi?,
      exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null()
    ]

    with false <- AddressView.contract_interaction_disabled?(),
         {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.find_contract_address(address_hash, address_options, true),
         false <- is_nil(address.smart_contract),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      render(
        conn,
        "index.html",
        base_params ++
          [
            address: address,
            non_custom_abi: true,
            coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
            counters_path: address_path(conn, :address_counters, %{"id" => Address.checksum(address_hash)}),
            tags: get_address_tags(address_hash, current_user(conn))
          ]
      )
    else
      _ ->
        if custom_abi? do
          with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
               {:ok, address} <- Chain.find_contract_address(address_hash, address_options, false),
               {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
            render(
              conn,
              "index.html",
              base_params ++
                [
                  address: address,
                  non_custom_abi: false,
                  coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
                  counters_path: address_path(conn, :address_counters, %{"id" => Address.checksum(address_hash)}),
                  tags: get_address_tags(address_hash, current_user(conn))
                ]
            )
          else
            _ ->
              not_found(conn)
          end
        else
          not_found(conn)
        end
    end
  end
end
