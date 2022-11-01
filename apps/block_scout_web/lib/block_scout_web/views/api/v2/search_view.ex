defmodule BlockScoutWeb.API.V2.SearchView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.Endpoint

  def render("search_results.json", %{search_results: search_results, next_page_params: next_page_params}) do
    %{"items" => Enum.map(search_results, &prepare_search_result/1), "next_page_params" => next_page_params}
  end

  def prepare_search_result(%{type: "token"} = search_result) do
    %{
      "type" => search_result.type,
      "name" => search_result.name,
      "symbol" => search_result.symbol,
      "address" => search_result.address_hash,
      "token_url" => token_path(Endpoint, :show, search_result.address_hash),
      "address_url" => address_path(Endpoint, :show, search_result.address_hash)
    }
  end

  def prepare_search_result(%{type: address_or_contract} = search_result)
      when address_or_contract in ["address", "contract"] do
    %{
      "type" => search_result.type,
      "name" => search_result.name,
      "address" => search_result.address_hash,
      "url" => address_path(Endpoint, :show, search_result.address_hash)
    }
  end

  def prepare_search_result(%{type: "block"} = search_result) do
    block_hash = hash_to_string(search_result.block_hash)

    %{
      "type" => search_result.type,
      "block_number" => search_result.block_number,
      "block_hash" => block_hash,
      "url" => block_path(Endpoint, :show, block_hash)
    }
  end

  def prepare_search_result(%{type: "transaction"} = search_result) do
    tx_hash = hash_to_string(search_result.tx_hash)

    %{
      "type" => search_result.type,
      "tx_hash" => tx_hash,
      "url" => transaction_path(Endpoint, :show, tx_hash)
    }
  end

  defp hash_to_string(hash), do: "0x" <> Base.encode16(hash, case: :lower)
end
