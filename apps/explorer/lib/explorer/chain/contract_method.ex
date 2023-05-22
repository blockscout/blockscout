defmodule Explorer.Chain.ContractMethod do
  @moduledoc """
  The representation of an individual item from the ABI of a verified smart contract.
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Hash, MethodIdentifier, SmartContract}
  alias Explorer.Repo

  @type t :: %__MODULE__{
          identifier: MethodIdentifier.t(),
          abi: map(),
          type: String.t()
        }

  schema "contract_methods" do
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

  defp abi_element_to_contract_method(element) do
    case ABI.parse_specification([element], include_events?: true) do
      [selector] ->
        now = DateTime.utc_now()

        %{
          identifier: selector.method_id,
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
