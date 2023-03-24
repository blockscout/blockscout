# credo:disable-for-this-file
#
# When moving the calls to ajax, this controller became very similar to the
# `address_contract_controller`, but both are necessary until we are able to
# address a better way to organize the controllers.
#
# So, for now, I'm adding this comment to disable the credo check for this file.
defmodule BlockScoutWeb.AddressReadContractController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]

  alias BlockScoutWeb.AccessHelpers
  alias BlockScoutWeb.AddressView
  alias Explorer.Celo.EpochUtil
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Explorer.ExchangeRates.Token
  alias Explorer.SmartContract.Reader
  alias Indexer.Fetcher.CoinBalanceOnDemand

  def index(conn, %{"address_id" => address_hash_string} = params) do
    address_options = [
      necessity_by_association: %{
        :contracts_creation_internal_transaction => :optional,
        :names => :optional,
        :smart_contract => :optional,
        :implementation_contract => :optional,
        :celo_account => :optional,
        :token => :optional,
        :contracts_creation_transaction => :optional
      }
    ]

    custom_abi = AddressView.fetch_custom_abi(conn, address_hash_string)
    custom_abi? = AddressView.check_custom_abi_for_having_read_functions(custom_abi)

    need_wallet_custom_abi? =
      !is_nil(custom_abi) && Reader.read_functions_required_wallet_from_abi(custom_abi.abi) != []

    base_params = [
      type: :regular,
      action: :read,
      custom_abi: custom_abi?,
      exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null()
    ]

    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.find_contract_address(address_hash, address_options, true),
         false <- is_nil(address.smart_contract),
         need_wallet? <- Reader.read_functions_required_wallet_from_abi(address.smart_contract.abi) != [],
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      render(
        conn,
        "index.html",
        base_params ++
          [
            address: address,
            non_custom_abi: true,
            need_wallet: need_wallet? || need_wallet_custom_abi?,
            coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
            counters_path: address_path(conn, :address_counters, %{"id" => Address.checksum(address_hash)}),
            tags: get_address_tags(address_hash, current_user(conn)),
            celo_epoch: EpochUtil.get_address_summary(address)
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
                  need_wallet: need_wallet_custom_abi?,
                  coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
                  counters_path: address_path(conn, :address_counters, %{"id" => Address.checksum(address_hash)}),
                  tags: get_address_tags(address_hash, current_user(conn)),
                  celo_epoch: EpochUtil.get_address_summary(address)
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
