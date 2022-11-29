defmodule Explorer.SmartContract.Helper do
  @moduledoc """
  SmartContract helper functions
  """

  import Ecto.Query

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.SmartContract
  alias Phoenix.HTML

  def queriable_method?(method) do
    method["constant"] || method["stateMutability"] == "view" || method["stateMutability"] == "pure"
  end

  def constructor?(function), do: function["type"] == "constructor"

  def event?(function), do: function["type"] == "event"

  def error?(function), do: function["type"] == "error"

  @doc """
    Checks whether the function which is not queriable can be consider as read function or not. 
  """
  @spec read_with_wallet_method?(%{}) :: true | false
  def read_with_wallet_method?(function),
    do:
      !error?(function) && !event?(function) && !constructor?(function) && nonpayable?(function) &&
        !empty_outputs?(function)

  def empty_inputs?(function), do: function["inputs"] == []

  def empty_outputs?(function), do: function["outputs"] == []

  def payable?(function), do: function["stateMutability"] == "payable" || function["payable"]

  def nonpayable?(function) do
    if function["type"] do
      function["stateMutability"] == "nonpayable" ||
        (!function["payable"] && !function["constant"] && !function["stateMutability"])
    else
      false
    end
  end

  def event_abi_to_topic_str(%{"type" => "event", "name" => name} = event) do
    types =
      event
      |> Map.get("inputs", [])
      |> Enum.map_join(",", & &1["type"])

    function_signature = "#{name}(#{types})"

    topic =
      function_signature
      |> ExKeccak.hash_256()
      |> Base.encode16(case: :lower)

    "0x" <> topic
  end

  @doc "Return all events on contract, return also implementation events if contract is a proxy."
  def get_all_events(%SmartContract{address_hash: address, abi: abi} = contract) do
    proxy = Chain.proxy_contract?(address, abi)

    events =
      if proxy do
        implementation_events =
          contract
          |> get_implementation_contract()
          |> then(&filter_events(&1.abi))

        implementation_events ++ filter_events(contract.abi)
      else
        filter_events(contract.abi)
      end

    # add the topic directly on the abi (not actually part of the abi itself but used ubiquitously)
    # then dedup by the topic
    events
    |> Enum.map(fn event -> Map.put(event, "topic", event_abi_to_topic_str(event)) end)
    |> Enum.uniq_by(&Map.get(&1, "topic"))
  end

  defp get_implementation_contract(%SmartContract{address_hash: address_hash, abi: abi}) do
    implementation_address = Chain.get_implementation_address_hash(address_hash, abi)
    {:ok, contract} = get_verified_contract(implementation_address)
    contract
  end

  defp filter_events(abi) do
    abi |> Enum.filter(&(&1["type"] == "event"))
  end

  def get_verified_contract(address_string) do
    case Explorer.Chain.Hash.Address.cast(address_string) do
      :error ->
        {:error, "Invalid format for address hash"}

      {:ok, address} ->
        query = from(sm in SmartContract, where: sm.address_hash == ^address)
        contract = query |> Repo.one()

        case contract do
          sm = %SmartContract{} ->
            {:ok, sm}

          nil ->
            {:error, "No verified contract found at address #{address_string}"}
        end
    end
  end

  def add_contract_code_md5(%{address_hash: address_hash_string} = attrs) when is_binary(address_hash_string) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      contract_code_md5 = contract_code_md5(address.contract_code.bytes)

      attrs
      |> Map.put_new(:contract_code_md5, contract_code_md5)
    else
      _ -> attrs
    end
  end

  def add_contract_code_md5(%{address_hash: address_hash} = attrs) do
    case Chain.hash_to_address(address_hash) do
      {:ok, address} ->
        contract_code_md5 = contract_code_md5(address.contract_code.bytes)

        attrs
        |> Map.put_new(:contract_code_md5, contract_code_md5)

      _ ->
        attrs
    end
  end

  def add_contract_code_md5(attrs), do: attrs

  def contract_code_md5(bytes) do
    :md5
    |> :crypto.hash(bytes)
    |> Base.encode16(case: :lower)
  end

  def sanitize_input(nil), do: nil

  def sanitize_input(input) do
    input
    |> HTML.html_escape()
    |> HTML.safe_to_string()
    |> String.trim()
  end
end
