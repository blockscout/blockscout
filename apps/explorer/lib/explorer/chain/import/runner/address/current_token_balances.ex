defmodule Explorer.Chain.Import.Runner.Address.CurrentTokenBalances do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.CurrentTokenBalance.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Import

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [CurrentTokenBalance.t()]

  @impl Import.Runner
  def ecto_schema_module, do: CurrentTokenBalance

  @impl Import.Runner
  def option_key, do: :address_current_token_balances

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
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, :address_current_token_balances, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout(),
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [CurrentTokenBalance.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options)
      when is_atom(repo) and is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        unique_token_balances(changes_list),
        conflict_target: ~w(address_hash token_contract_address_hash)a,
        on_conflict: on_conflict,
        for: CurrentTokenBalance,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  # Remove duplicated token balances based on `{address_hash, token_hash}` considering the last block
  # to avoid `cardinality_violation` error in Postgres. This error happens when there are duplicated
  # rows being inserted.
  defp unique_token_balances(changes_list) do
    changes_list
    |> Enum.sort(&(&1.block_number > &2.block_number))
    |> Enum.uniq_by(fn %{address_hash: address_hash, token_contract_address_hash: token_hash} ->
      {address_hash, token_hash}
    end)
  end

  defp default_on_conflict do
    from(
      current_token_balance in CurrentTokenBalance,
      update: [
        set: [
          block_number:
            fragment(
              "CASE WHEN EXCLUDED.block_number > ? THEN EXCLUDED.block_number ELSE ? END",
              current_token_balance.block_number,
              current_token_balance.block_number
            ),
          inserted_at:
            fragment(
              "CASE WHEN EXCLUDED.block_number > ? THEN EXCLUDED.inserted_at ELSE ? END",
              current_token_balance.block_number,
              current_token_balance.inserted_at
            ),
          updated_at:
            fragment(
              "CASE WHEN EXCLUDED.block_number > ? THEN EXCLUDED.updated_at ELSE ? END",
              current_token_balance.block_number,
              current_token_balance.updated_at
            ),
          value:
            fragment(
              "CASE WHEN EXCLUDED.block_number > ? THEN EXCLUDED.value ELSE ? END",
              current_token_balance.block_number,
              current_token_balance.value
            ),
          value_fetched_at:
            fragment(
              "CASE WHEN EXCLUDED.block_number > ? THEN EXCLUDED.value_fetched_at ELSE ? END",
              current_token_balance.block_number,
              current_token_balance.value_fetched_at
            )
        ]
      ]
    )
  end
end
