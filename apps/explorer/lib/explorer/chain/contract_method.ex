defmodule Explorer.Chain.ContractMethod do
  @moduledoc """
  The representation of an individual item from the ABI of a verified smart contract.
  """

  require Logger

  import Ecto.Query, only: [from: 2]
  use Explorer.Schema

  alias Explorer.Chain.{Hash, MethodIdentifier, SmartContract}
  alias Explorer.{Chain, Repo}

  typed_schema "contract_methods" do
    field(:identifier, MethodIdentifier)
    field(:abi, :map)
    field(:type, :string)

    timestamps()
  end

  def upsert_from_abi(abi, address_hash) do
    {successes, errors} =
      abi
      |> Enum.reject(fn selector ->
        Map.get(selector, "type") in ["fallback", "constructor"]
      end)
      |> Enum.reduce({[], []}, fn selector, {successes, failures} ->
        case abi_element_to_contract_method(selector) do
          {:error, message} ->
            {successes, [message | failures]}

          selector ->
            {[selector | successes], failures}
        end
      end)

    unless Enum.empty?(errors) do
      Logger.error(fn ->
        ["Error parsing some abi elements at ", Hash.to_iodata(address_hash), ": ", Enum.intersperse(errors, "\n")]
      end)
    end

    # Enforce ContractMethod ShareLocks order (see docs: sharelocks.md)
    ordered_successes = Enum.sort_by(successes, &{&1.identifier, &1.abi})

    Repo.insert_all(__MODULE__, ordered_successes, on_conflict: :nothing, conflict_target: [:identifier, :abi])
  end

  def import_all do
    result =
      Repo.transaction(fn ->
        SmartContract
        |> Repo.stream()
        |> Task.async_stream(fn contract ->
          upsert_from_abi(contract.abi, contract.address_hash)
        end)
        |> Stream.run()
      end)

    case result do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Query that finds limited number of contract methods by selector id
  """
  @spec find_contract_method_query(binary(), integer()) :: Ecto.Query.t()
  def find_contract_method_query(method_id, limit) do
    from(
      contract_method in __MODULE__,
      where: contract_method.identifier == ^method_id,
      order_by: [asc: contract_method.inserted_at],
      limit: ^limit
    )
  end

  @doc """
  Finds contract method by selector id
  """
  @spec find_contract_method_by_selector_id(binary(), [Chain.api?()]) :: __MODULE__.t() | nil
  def find_contract_method_by_selector_id(method_id, options) do
    query =
      from(
        contract_method in __MODULE__,
        where: contract_method.abi["type"] == "function",
        where: contract_method.identifier == ^method_id,
        limit: 1
      )

    Chain.select_repo(options).one(query)
  end

  @spec find_contract_method_by_name(String.t(), [Chain.api?()]) :: __MODULE__.t() | nil
  def find_contract_method_by_name(name, options) do
    query =
      from(
        contract_method in __MODULE__,
        where: contract_method.abi["type"] == "function",
        where: contract_method.abi["name"] == ^name,
        limit: 1
      )

    Chain.select_repo(options).one(query)
  end

  @doc """
  Finds contract methods by selector id
  """
  @spec find_contract_methods([binary()], [Chain.api?()]) :: [__MODULE__.t()]
  def find_contract_methods(method_ids, options)

  def find_contract_methods([], _), do: []

  def find_contract_methods(method_ids, options) do
    query =
      from(
        contract_method in __MODULE__,
        distinct: contract_method.identifier,
        where: contract_method.abi["type"] == "function",
        where: contract_method.identifier in ^method_ids,
        order_by: [asc: contract_method.identifier, asc: contract_method.inserted_at]
      )

    Chain.select_repo(options).all(query)
  end

  defp abi_element_to_contract_method(element) do
    case ABI.parse_specification([element], include_events?: true) do
      [selector] ->
        now = DateTime.utc_now()

        # For events, the method_id (signature) is 32 bytes, whereas for methods
        # and errors it is 4 bytes. To avoid complications with different sizes,
        # we always take only the first 4 bytes of the hash.
        <<first_four_bytes::binary-size(4), _::binary>> = selector.method_id

        {:ok, method_id} = MethodIdentifier.cast(first_four_bytes)

        %{
          identifier: method_id,
          abi: element,
          type: Atom.to_string(selector.type),
          inserted_at: now,
          updated_at: now
        }

      _ ->
        {:error, "Failed to parse abi row."}
    end
  rescue
    e ->
      message = Exception.format(:error, e, __STACKTRACE__)

      {:error, message}
  end
end
