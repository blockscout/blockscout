defmodule Explorer.Chain.ContractMethod do
  @moduledoc """
  The representation of an individual item from the ABI of a verified smart contract.
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Hash, MethodIdentifier}
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

    Repo.insert_all(__MODULE__, successes, on_conflict: :nothing, conflict_target: [:identifier, :abi])
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
      message = Exception.format(:error, e)

      {:error, message}
  end
end
