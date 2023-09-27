defmodule BlockScoutWeb.API.V2.SearchView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.{BlockView, Endpoint}
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Block, Hash, Transaction}

  def render("search_results.json", %{search_results: search_results, next_page_params: next_page_params}) do
    %{"items" => Enum.map(search_results, &prepare_search_result/1), "next_page_params" => next_page_params}
  end

  def render("search_results.json", %{search_results: search_results}) do
    Enum.map(search_results, &prepare_search_result/1)
  end

  def render("search_results.json", %{result: {:ok, result}}) do
    Map.merge(%{"redirect" => true}, redirect_search_results(result))
  end

  def render("search_results.json", %{result: {:error, :not_found}}) do
    %{"redirect" => false, "type" => nil, "parameter" => nil}
  end

  def prepare_search_result(%{type: "token"} = search_result) do
    %{
      "type" => search_result.type,
      "name" => search_result.name,
      "symbol" => search_result.symbol,
      "address" => search_result.address_hash,
      "token_url" => token_path(Endpoint, :show, search_result.address_hash),
      "address_url" => address_path(Endpoint, :show, search_result.address_hash),
      "icon_url" => search_result.icon_url,
      "token_type" => search_result.token_type,
      "is_smart_contract_verified" => search_result.verified,
      "exchange_rate" => search_result.exchange_rate && to_string(search_result.exchange_rate),
      "total_supply" => search_result.total_supply,
      "circulating_market_cap" =>
        search_result.circulating_market_cap && to_string(search_result.circulating_market_cap),
      "is_verified_via_admin_panel" => search_result.is_verified_via_admin_panel
    }
  end

  def prepare_search_result(%{type: address_or_contract_or_label} = search_result)
      when address_or_contract_or_label in ["address", "contract", "label"] do
    %{
      "type" => search_result.type,
      "name" => search_result.name,
      "address" => search_result.address_hash,
      "url" => address_path(Endpoint, :show, search_result.address_hash),
      "is_smart_contract_verified" => search_result.verified
    }
  end

  def prepare_search_result(%{type: "block"} = search_result) do
    block_hash = hash_to_string(search_result.block_hash)

    {:ok, block} =
      Chain.hash_to_block(hash(search_result.block_hash),
        necessity_by_association: %{
          :nephews => :optional
        },
        api?: true
      )

    %{
      "type" => search_result.type,
      "block_number" => search_result.block_number,
      "block_hash" => block_hash,
      "url" => block_path(Endpoint, :show, block_hash),
      "timestamp" => search_result.timestamp,
      "block_type" => block |> BlockView.block_type() |> String.downcase()
    }
  end

  def prepare_search_result(%{type: "transaction"} = search_result) do
    tx_hash = hash_to_string(search_result.tx_hash)

    %{
      "type" => search_result.type,
      "tx_hash" => tx_hash,
      "url" => transaction_path(Endpoint, :show, tx_hash),
      "timestamp" => search_result.timestamp
    }
  end

  defp hash_to_string(%Hash{bytes: bytes}), do: hash_to_string(bytes)
  defp hash_to_string(hash), do: "0x" <> Base.encode16(hash, case: :lower)

  defp hash(%Hash{} = hash), do: hash

  defp hash(bytes),
    do: %Hash{
      byte_count: 32,
      bytes: bytes
    }

  defp redirect_search_results(%Address{} = item) do
    %{"type" => "address", "parameter" => Address.checksum(item.hash)}
  end

  defp redirect_search_results(%Block{} = item) do
    %{"type" => "block", "parameter" => to_string(item.hash)}
  end

  defp redirect_search_results(%Transaction{} = item) do
    %{"type" => "transaction", "parameter" => to_string(item.hash)}
  end
end
