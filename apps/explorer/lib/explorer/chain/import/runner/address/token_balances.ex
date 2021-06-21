defmodule Explorer.Chain.Import.Runner.Address.TokenBalances do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.TokenBalance.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Chain.Import

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [TokenBalance.t()]

  @impl Import.Runner
  def ecto_schema_module, do: TokenBalance

  @impl Import.Runner
  def option_key, do: :address_token_balances

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

    Multi.run(multi, :address_token_balances, fn repo, _ ->
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
          {:ok, [TokenBalance.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce TokenBalance ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list =
      Enum.sort_by(changes_list, &{&1.token_contract_address_hash, &1.address_hash, &1.block_number})

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: ~w(address_hash token_contract_address_hash block_number)a,
        on_conflict: on_conflict,
        for: TokenBalance,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      token_balance in TokenBalance,
      update: [
        set: [
          value: fragment("EXCLUDED.value"),
          value_fetched_at: fragment("EXCLUDED.value_fetched_at"),
          inserted_at: fragment("LEAST(EXCLUDED.inserted_at, ?)", token_balance.inserted_at),
          updated_at: fragment("GREATEST(EXCLUDED.updated_at, ?)", token_balance.updated_at)
        ]
      ],
      where:
        fragment("EXCLUDED.value IS NOT NULL") and
          (is_nil(token_balance.value_fetched_at) or
             fragment("? < EXCLUDED.value_fetched_at", token_balance.value_fetched_at))
    )
  end
end
