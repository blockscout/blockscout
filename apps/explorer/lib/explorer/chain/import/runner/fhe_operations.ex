defmodule Explorer.Chain.Import.Runner.FheOperations do
  @moduledoc """
  Bulk imports FHE operations parsed from transaction logs.

  This runner handles the database insertion of FHE operations that were parsed
  during block indexing. It follows the standard Blockscout import runner pattern
  with proper conflict resolution and error handling.

  Also check sets FHE contract tags.
  """

  require Ecto.Query
  require Logger

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.{FheOperation, Import, Hash, Transaction}
  alias Explorer.Chain.FheContractChecker
  alias Explorer.Repo

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # Required by Import.Runner behaviour
  @impl Import.Runner
  def ecto_schema_module, do: FheOperation

  @impl Import.Runner
  def option_key, do: :fhe_operations

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.put_new(:timeout, timeout())
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, :insert_fhe_operations, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @timeout 60_000

  @spec insert(Repo.t(), [map()], %{
          required(:timeout) => timeout(),
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [FheOperation.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps}) when is_list(changes_list) do
    # Return early if no FHE operations to insert
    if Enum.empty?(changes_list) do
      {:ok, []}
    else
      # Order by transaction_hash and log_index for deterministic insertion
      ordered_changes_list =
        changes_list
        |> Enum.sort_by(&{&1.transaction_hash, &1.log_index})

      # Insert with conflict resolution
      # If the same operation exists (same transaction_hash + log_index), replace it
      {:ok, inserted} =
        Import.insert_changes_list(
          repo,
          ordered_changes_list,
          conflict_target: [:transaction_hash, :log_index],
          on_conflict: :replace_all,
          for: FheOperation,
          returning: true,
          timeout: timeout,
          timestamps: timestamps
        )

      tag_contracts_from_fhe_operations(ordered_changes_list)

      {:ok, inserted}
    end
  end
  
  # Tags contracts that were called in transactions with FHE operations
  defp tag_contracts_from_fhe_operations(fhe_operations) when is_list(fhe_operations) do
    if Enum.empty?(fhe_operations) do
      :ok
    else
      contract_addresses = get_all_contract_addresses_from_fhe_operations(fhe_operations)


      Enum.each(contract_addresses, fn address_hash ->
         FheContractChecker.check_and_save_fhe_status(address_hash, [])
      end)

      :ok
    end
  end

  defp tag_contracts_from_fhe_operations(_), do: :ok

  # Gets all unique contract addresses from FHE operations:
  # 1. Caller addresses from FHE operation logs (contracts that called FHE operations)
  # 2. Transaction to_addresses (contracts that were called in transactions with FHE operations)
  defp get_all_contract_addresses_from_fhe_operations(fhe_operations) do
    # Get caller addresses from FHE operation logs
    caller_addresses =
      fhe_operations
      |> Enum.map(& &1.caller)
      |> Enum.filter(&(not is_nil(&1)))
      |> Enum.uniq()

    # Get transaction to_addresses from transactions with FHE operations
    transaction_hashes =
      fhe_operations
      |> Enum.map(& &1.transaction_hash)
      |> Enum.uniq()

    to_addresses =
      from(
        t in Transaction,
        where: t.hash in ^transaction_hashes,
        where: not is_nil(t.to_address_hash),
        select: t.to_address_hash,
        distinct: true
      )
      |> Repo.all()

    # Combine and deduplicate
    (caller_addresses ++ to_addresses) |> Enum.uniq()
  end
end
