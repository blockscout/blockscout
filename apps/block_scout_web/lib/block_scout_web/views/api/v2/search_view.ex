defmodule BlockScoutWeb.API.V2.SearchView do
  use BlockScoutWeb, :view
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias BlockScoutWeb.{BlockView, Endpoint}
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Beacon.Blob, Block, Hash, Transaction, UserOperation}
  alias Plug.Conn.Query

  def render("search_results.json", %{search_results: search_results, next_page_params: next_page_params}) do
    %{
      "items" => search_results |> Enum.map(&prepare_search_result/1) |> chain_type_fields(),
      "next_page_params" => next_page_params |> encode_next_page_params()
    }
  end

  def render("search_results.json", %{search_results: search_results}) do
    search_results |> Enum.map(&prepare_search_result/1) |> chain_type_fields()
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
      "address_hash" => search_result.address_hash,
      # todo: It should be removed in favour `address_hash` property with the next release after 8.0.0
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
      "is_verified_via_admin_panel" => search_result.is_verified_via_admin_panel,
      "certified" => search_result.certified || false,
      "priority" => search_result.priority
    }
  end

  def prepare_search_result(%{type: "contract"} = search_result) do
    %{
      "type" => search_result.type,
      "name" => search_result.name,
      "address_hash" => search_result.address_hash,
      # todo: It should be removed in favour `address_hash` property with the next release after 8.0.0
      "address" => search_result.address_hash,
      "url" => address_path(Endpoint, :show, search_result.address_hash),
      "is_smart_contract_verified" => search_result.verified,
      "ens_info" => search_result[:ens_info],
      "certified" => if(search_result.certified, do: search_result.certified, else: false),
      "priority" => search_result.priority
    }
  end

  def prepare_search_result(%{type: address_or_contract_or_label} = search_result)
      when address_or_contract_or_label in ["address", "label", "ens_domain"] do
    %{
      "type" => search_result.type,
      "name" => search_result.name,
      "address_hash" => search_result.address_hash,
      # todo: It should be removed in favour `address_hash` property with the next release after 8.0.0
      "address" => search_result.address_hash,
      "url" => address_path(Endpoint, :show, search_result.address_hash),
      "is_smart_contract_verified" => search_result.verified,
      "ens_info" => search_result[:ens_info],
      "certified" => if(search_result.certified, do: search_result.certified, else: false),
      "priority" => search_result.priority
    }
  end

  def prepare_search_result(%{type: "metadata_tag"} = search_result) do
    %{
      "type" => search_result.type,
      "name" => search_result.name,
      "address_hash" => search_result.address_hash,
      # todo: It should be removed in favour `address_hash` property with the next release after 8.0.0
      "address" => search_result.address_hash,
      "url" => address_path(Endpoint, :show, search_result.address_hash),
      "is_smart_contract_verified" => search_result.verified,
      "ens_info" => search_result[:ens_info],
      "certified" => if(search_result.certified, do: search_result.certified, else: false),
      "priority" => search_result.priority,
      "metadata" => search_result.metadata
    }
  end

  def prepare_search_result(%{type: "block"} = search_result) do
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
      "block_hash" => block.hash,
      "url" => block_path(Endpoint, :show, block.hash),
      "timestamp" => search_result.timestamp,
      "block_type" => block |> BlockView.block_type() |> String.downcase(),
      "priority" => search_result.priority
    }
  end

  def prepare_search_result(%{type: "transaction"} = search_result) do
    transaction_hash = hash_to_string(search_result.transaction_hash)

    %{
      "type" => search_result.type,
      "transaction_hash" => transaction_hash,
      "url" => transaction_path(Endpoint, :show, transaction_hash),
      "timestamp" => search_result.timestamp,
      "priority" => search_result.priority
    }
  end

  def prepare_search_result(%{type: "user_operation"} = search_result) do
    %{
      "type" => search_result.type,
      "user_operation_hash" => hash_to_string(search_result.user_operation_hash),
      "timestamp" => search_result.timestamp,
      "priority" => search_result.priority
    }
  end

  def prepare_search_result(%{type: "blob"} = search_result) do
    %{
      "type" => search_result.type,
      "blob_hash" => hash_to_string(search_result.blob_hash),
      "timestamp" => search_result.timestamp,
      "priority" => search_result.priority
    }
  end

  def prepare_search_result(%{type: "tac_operation"} = search_result) do
    %{
      "type" => search_result.type,
      "tac_operation" => search_result.tac_operation,
      "priority" => search_result.priority
    }
  end

  defp hash_to_string(%Hash{} = hash), do: to_string(hash)

  defp hash_to_string(bytes) do
    {:ok, hash} = Hash.Full.cast(bytes)
    to_string(hash)
  end

  defp hash(%Hash{} = hash), do: hash

  defp hash(bytes),
    do: %Hash{
      byte_count: 32,
      bytes: bytes
    }

  defp redirect_search_results(%Address{} = item) do
    %{"type" => "address", "parameter" => Address.checksum(item.hash)}
  end

  defp redirect_search_results(%{address_hash: address_hash}) do
    %{"type" => "address", "parameter" => address_hash}
  end

  defp redirect_search_results(%Block{} = item) do
    %{"type" => "block", "parameter" => to_string(item.hash)}
  end

  defp redirect_search_results(%Transaction{} = item) do
    %{"type" => "transaction", "parameter" => to_string(item.hash)}
  end

  defp redirect_search_results(%UserOperation{} = item) do
    %{"type" => "user_operation", "parameter" => to_string(item.hash)}
  end

  defp redirect_search_results(%Blob{} = item) do
    %{"type" => "blob", "parameter" => to_string(item.hash)}
  end

  case @chain_type do
    :filecoin ->
      defp chain_type_fields(result) do
        # credo:disable-for-next-line Credo.Check.Design.AliasUsage
        BlockScoutWeb.API.V2.FilecoinView.preload_and_put_filecoin_robust_address_to_search_results(result)
      end

    _ ->
      defp chain_type_fields(result) do
        result
      end
  end

  defp encode_next_page_params(next_page_params) when is_map(next_page_params) do
    result =
      next_page_params
      |> Query.encode()
      |> URI.decode_query()
      |> Enum.map(fn {k, v} ->
        {k, unless(v == "", do: v)}
      end)
      |> Enum.into(%{})

    unless result == %{} do
      result
    end
  end

  defp encode_next_page_params(next_page_params), do: next_page_params
end
