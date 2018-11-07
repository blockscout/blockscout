defmodule BlockScoutWeb.AddressValidationController do
  @moduledoc """
  Display all the blocks that this address validates.
  """
  use BlockScoutWeb, :controller

  import BlockScoutWeb.AddressController, only: [transaction_count: 1, validation_count: 1]
  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.BlockView
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Phoenix.View

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.find_or_insert_address_from_hash(address_hash) do
      full_options =
        Keyword.merge(
          [
            necessity_by_association: %{
              miner: :required,
              nephews: :optional,
              transactions: :optional
            }
          ],
          paging_options(params)
        )

      blocks_plus_one = Chain.get_blocks_validated_by_address(full_options, address)
      {blocks, next_page} = split_list_by_page(blocks_plus_one)

      next_page_url =
        case next_page_params(next_page, blocks, params) do
          nil ->
            nil

          next_page_params ->
            address_validation_path(
              conn,
              :index,
              address,
              next_page_params
            )
        end

      json(
        conn,
        %{
          validated_blocks:
            Enum.map(blocks, fn block ->
              %{
                block_number: block.number,
                block_html:
                  View.render_to_string(
                    BlockView,
                    "_tile.html",
                    block: block,
                    block_type: BlockView.block_type(block)
                  )
              }
            end),
          next_page_url: next_page_url
        }
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.find_or_insert_address_from_hash(address_hash) do
      full_options =
        Keyword.merge(
          [
            necessity_by_association: %{
              miner: :required,
              nephews: :optional,
              transactions: :optional
            }
          ],
          paging_options(%{})
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
