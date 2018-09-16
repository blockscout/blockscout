defmodule BlockScoutWeb.AddressValidationController do
  @moduledoc """
    Display all the blocks that this address validates.
  """
  use BlockScoutWeb, :controller

  import BlockScoutWeb.AddressController, only: [transaction_count: 1, validation_count: 1]
  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      full_options =
        Keyword.merge(
          [necessity_by_association: %{miner: :required, transactions: :optional}],
          paging_options(params)
        )

      blocks_plus_one = Chain.get_blocks_validated_by_address(full_options, address)
      {blocks, next_page} = split_list_by_page(blocks_plus_one)

      render(
        conn,
        "index.html",
        address: address,
        blocks: blocks,
        transaction_count: transaction_count(address),
        validation_count: validation_count(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        next_page_params: next_page_params(next_page, blocks, params)
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
