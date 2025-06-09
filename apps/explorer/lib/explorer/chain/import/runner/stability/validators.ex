defmodule Explorer.Chain.Import.Runner.Stability.Validators do
  @moduledoc """
  Bulk updates `t:Explorer.Chain.Stability.Validator.t/0` blocks_validated counters.
  """

  require Ecto.Query

  alias Ecto.{Multi, Repo}
  alias Explorer.Chain.{Import, Stability.Validator}
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2, where: 3]

  require Logger

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Validator.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Validator

  @impl Import.Runner
  def option_key, do: :stability_validators

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s with updated counters"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, :stability_validators, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> update_counters(repo, changes_list, insert_options) end,
        :block_referencing,
        :stability_validators,
        :stability_validators
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec update_counters(Repo.t(), [map()], %{
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [Validator.t()]}
  defp update_counters(repo, changes_list, %{timeout: timeout, timestamps: timestamps}) when is_list(changes_list) do
    if changes_list != [] do
      # Get all address hashes from the changes
      address_hashes = Enum.map(changes_list, & &1.address_hash)

      # Get existing validators that match the address hashes
      existing_validators =
        Validator
        |> where([v], v.address_hash in ^address_hashes)
        |> repo.all(timeout: timeout)

      # Update counters for each existing validator
      updated_validators =
        Enum.reduce(changes_list, [], fn change, acc ->
          case Enum.find(existing_validators, &(&1.address_hash == change.address_hash)) do
            nil ->
              # Validator doesn't exist, log error and skip
              Logger.error("Validator with address hash #{to_string(change.address_hash)} not found")
              acc

            validator ->
              # Update the blocks_validated counter
              # credo:disable-for-next-line
              case repo.update_all(
                     from(v in Validator, where: v.address_hash == ^change.address_hash),
                     [
                       inc: [blocks_validated: change.blocks_validated],
                       set: [updated_at: timestamps.updated_at]
                     ],
                     timeout: timeout
                   ) do
                {1, _} ->
                  # Successfully updated, add to result
                  updated_validator = %Validator{
                    address_hash: change.address_hash,
                    blocks_validated: validator.blocks_validated + change.blocks_validated
                  }

                  [updated_validator | acc]

                _ ->
                  # Update failed, log error and skip
                  Logger.error("Failed to update validator counter for address hash #{to_string(change.address_hash)}")
                  acc
              end
          end
        end)

      {:ok, updated_validators}
    else
      {:ok, []}
    end
  end
end
