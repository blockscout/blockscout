defmodule Explorer.Chain.FheContractChecker do
  @moduledoc """
  Helper module to check if a contract is a Confidential/FHE contract.
  Uses the confidentialProtocolId() function to determine if a contract uses FHE.
  """
  require Logger

  import Ecto.Query, only: [from: 2]
  import Explorer.Chain, only: [select_repo: 1]
  import EthereumJSONRPC, only: [json_rpc: 2]

  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Repo
  alias Explorer.Tags.{AddressTag, AddressToTag}
  alias EthereumJSONRPC.Contract

  @confidential_protocol_id_selector "0x8927b030"
  @fhe_tag_label "fhe"
  @fhe_tag_display_name "FHE"

  @doc """
  Checks if a contract is FHE and saves the result as a tag in the database.
  """
  @spec check_and_save_fhe_status(Hash.Address.t() | nil, Keyword.t()) :: :ok | :empty | :error | :already_checked
  def check_and_save_fhe_status(address_hash, options \\ [])

  def check_and_save_fhe_status(address_hash, options) when not is_nil(address_hash) do
    address = Address.get(address_hash, options)

    if Address.smart_contract?(address) and not is_nil(address.contract_code) do
      if already_checked?(address_hash, options) do
         :already_checked
      else
        case is_fhe_contract?(address_hash) do
          {:ok, true} ->
            save_fhe_tag(address_hash, options)
          {:ok, false} ->
            :ok
          _error ->
            :error
        end
      end
    else
      :empty
    end
  end

  def check_and_save_fhe_status(_, _), do: :empty

  @doc """
  Checks if a contract is a Confidential/FHE contract by calling confidentialProtocolId()
  """
  @spec is_fhe_contract?(Hash.Address.t()) :: {:ok, boolean()}
  def is_fhe_contract?(%Hash{byte_count: 20} = address_hash) do
    address_string = Hash.to_string(address_hash)

    request = Contract.eth_call_request(@confidential_protocol_id_selector, address_string, 0, nil, nil)
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    case json_rpc(request, json_rpc_named_arguments) do
      {:ok, result} when is_binary(result) -> 
        is_fhe = decode_uint256(result) != 0
        {:ok, is_fhe}
      {:ok, [%{result: result}]} when is_binary(result) -> 
        is_fhe = decode_uint256(result) != 0
        {:ok, is_fhe}
      {:ok, _other} ->
        {:ok, false}
      {:error, _reason} ->
        {:ok, false} # Treat RPC error as false to avoid crashing/retrying loop, or return error?
      _other ->
        {:ok, false}
    end
  end

  def is_fhe_contract?(address_hash_string) when is_binary(address_hash_string) do
    case Hash.Address.cast(address_hash_string) do
      {:ok, address_hash} -> is_fhe_contract?(address_hash)
      _ -> 
        {:error, :invalid_hash}
    end
  end

  @doc """
  Checks if an address has already been tagged as FHE.
  """
  @spec already_checked?(Hash.Address.t(), Keyword.t()) :: boolean()
  def already_checked?(address_hash, options) do
    tag_id = AddressTag.get_id_by_label(@fhe_tag_label)
    
    if tag_id do
      repo = select_repo(options)
      str_hash = Hash.to_string(address_hash)

      from(att in AddressToTag, 
        where: att.tag_id == ^tag_id and att.address_hash == ^str_hash
      ) |> repo.exists?()
    else
      false
    end
  end

  defp save_fhe_tag(address_hash, _options) do
    ensure_fhe_tag_exists()
    
    case AddressTag.get_id_by_label(@fhe_tag_label) do
      nil -> :error
      tag_id -> insert_tag_mapping(address_hash, tag_id)
    end
  end

  defp insert_tag_mapping(address_hash, tag_id) do
    params = %{
      address_hash: address_hash,
      tag_id: tag_id,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
    
    # We use Repo.insert_all with on_conflict: :nothing to be safe and idempotent
    Repo.insert_all(AddressToTag, [params], on_conflict: :nothing, conflict_target: [:address_hash, :tag_id])
    :ok
  rescue
    e ->
      Logger.error("Failed to insert FHE tag mapping: #{inspect(e)}")
      :error
  end

  defp ensure_fhe_tag_exists do
    case AddressTag.set(@fhe_tag_label, @fhe_tag_display_name) do
      {:ok, _} -> :ok
      {:error, %Ecto.Changeset{errors: [label: {_, [constraint: :unique, constraint_name: "address_tags_label_index"]}]}} -> :ok
      _ -> :error
    end
  end

  defp decode_uint256("0x" <> hex), do: decode_hex(hex)
  defp decode_uint256(hex) when is_binary(hex), do: decode_hex(hex)
  defp decode_uint256(_), do: 0

  defp decode_hex(""), do: 0
  defp decode_hex(hex) do
    hex |> String.trim_leading("0") |> case do
      "" -> 0
      val -> String.to_integer(val, 16)
    end
  end
end
