defmodule BlockScoutWeb.AddressContractView do
  use BlockScoutWeb, :view

  require Logger

  import Explorer.Helper, only: [decode_data: 2]
  import Phoenix.LiveView.Helpers, only: [sigil_H: 2]

  alias ABI.FunctionSelector
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Data, InternalTransaction, Transaction}
  alias Explorer.Chain.SmartContract
  alias Explorer.Chain.SmartContract.Proxy.EIP1167
  alias Explorer.SmartContract.Helper, as: SmartContractHelper
  alias Phoenix.HTML.Safe

  def render("scripts.html", %{conn: conn}) do
    render_scripts(conn, "address_contract/code_highlighting.js")
  end

  def format_smart_contract_abi(abi) when not is_nil(abi), do: Poison.encode!(abi, %{pretty: false})

  @doc """
  Returns the correct format for the optimization text.

    iex> BlockScoutWeb.AddressContractView.format_optimization_text(true)
    "true"

    iex> BlockScoutWeb.AddressContractView.format_optimization_text(false)
    "false"
  """
  def format_optimization_text(true), do: gettext("true")
  def format_optimization_text(false), do: gettext("false")

  def format_constructor_arguments(contract, conn) do
    constructor_abi = Enum.find(contract.abi, fn el -> el["type"] == "constructor" && el["inputs"] != [] end)

    input_types = Enum.map(constructor_abi["inputs"], &FunctionSelector.parse_specification_type/1)

    {_, result} =
      contract.constructor_arguments
      |> decode_data(input_types)
      |> Enum.zip(constructor_abi["inputs"])
      |> Enum.reduce({0, "#{contract.constructor_arguments}\n\n"}, fn {val, %{"type" => type}}, {count, acc} ->
        formatted_val = val_to_string(val, type, conn)
        assigns = %{acc: acc, count: count, type: type, formatted_val: formatted_val}

        {count + 1,
         ~H"""
         <%= @acc %> Arg [<%= @count %>] (<b><%= @type %></b>) : <%= @formatted_val %>
         """
         |> Safe.to_iodata()
         |> List.to_string()}
      end)

    result
  rescue
    _ -> contract.constructor_arguments
  end

  defp val_to_string(val, type, conn) do
    cond do
      type =~ "[]" ->
        val_to_string_if_array(val, type, conn)

      type =~ "address" ->
        address_hash = "0x" <> Base.encode16(val, case: :lower)

        address = Chain.string_to_address_hash_or_nil(address_hash)

        get_formatted_address_data(address, address_hash, conn)

      type =~ "bytes" ->
        Base.encode16(val, case: :lower)

      true ->
        to_string(val)
    end
  end

  defp val_to_string_if_array(val, type, conn) do
    if is_list(val) or is_tuple(val) do
      "[" <>
        Enum.map_join(val, ", ", fn el -> val_to_string(el, String.replace_suffix(type, "[]", ""), conn) end) <> "]"
    else
      to_string(val)
    end
  end

  defp get_formatted_address_data(address, address_hash, conn) do
    if address != nil do
      assigns = %{address: address, address_hash: address_hash, conn: conn}

      ~H"""
      <a href="{#{address_path(@conn, :show, @address)}}"><%= @address_hash %></a>
      """
    else
      address_hash
    end
  end

  def format_external_libraries(libraries, conn) do
    Enum.reduce(libraries, "", fn %{name: name, address_hash: address_hash}, acc ->
      address = Chain.string_to_address_hash_or_nil(address_hash)
      assigns = %{acc: acc, name: name, address: address, address_hash: address_hash, conn: conn}

      ~H"""
      <%= @acc %><span class="hljs-title"><%= @name %></span> : <%= get_formatted_address_data(@address, @address_hash, @conn) %>
      """
      |> Safe.to_iodata()
      |> List.to_string()
    end)
  end

  def contract_creation_code(%Address{
        contract_creation_transaction: %Transaction{
          status: :error,
          input: creation_code
        }
      }) do
    {:failed, creation_code}
  end

  def contract_creation_code(%Address{
        contract_creation_internal_transaction: %InternalTransaction{
          error: error,
          init: init
        }
      })
      when not is_nil(error) do
    {:failed, init}
  end

  def contract_creation_code(%Address{
        contract_code: %Data{bytes: <<>>},
        contract_creation_internal_transaction: %InternalTransaction{init: init}
      }) do
    {:selfdestructed, init}
  end

  def contract_creation_code(%Address{contract_code: contract_code}) do
    {:ok, contract_code}
  end

  def creation_code(%Address{contract_creation_transaction: %Transaction{}} = address) do
    address.contract_creation_transaction.input
  end

  def creation_code(%Address{contract_creation_internal_transaction: %InternalTransaction{}} = address) do
    address.contract_creation_internal_transaction.init
  end

  def creation_code(%Address{contract_creation_transaction: nil}) do
    nil
  end

  def sourcify_repo_url(address_hash, partial_match) do
    checksummed_hash = Address.checksum(address_hash)
    chain_id = Application.get_env(:explorer, Explorer.ThirdPartyIntegrations.Sourcify)[:chain_id]
    repo_url = Application.get_env(:explorer, Explorer.ThirdPartyIntegrations.Sourcify)[:repo_url]
    match = if partial_match, do: "/partial_match/", else: "/full_match/"

    if chain_id do
      repo_url <> match <> chain_id <> "/" <> checksummed_hash <> "/"
    else
      Logger.warning("chain_id is nil. Please set CHAIN_ID env variable.")
      nil
    end
  end
end
