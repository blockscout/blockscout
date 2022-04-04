defmodule Explorer.Chain.Import.Runner.Address.TokenBalances do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.TokenBalance.t/0`.
  """

  require Ecto.Query
  require Logger

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
    Logger.info("### Address_token_balances run STARTED changes_list length #{Enum.count(changes_list)} ###")

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
    {:ok, []}
    # todo
    # Logger.info("### Address_token_balances insert started changes_list length #{Enum.count(changes_list)} ###")
    # on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # # Enforce TokenBalance ShareLocks order (see docs: sharelocks.md)
    # %{
    #   changes_list_no_token_id: changes_list_no_token_id,
    #   changes_list_with_token_id: changes_list_with_token_id
    # } =
    #   changes_list
    #   |> Enum.reduce(%{changes_list_no_token_id: [], changes_list_with_token_id: []}, fn change, acc ->
    #     updated_change =
    #       if Map.has_key?(change, :token_id) and Map.get(change, :token_type) == "ERC-1155" do
    #         change
    #       else
    #         Map.put(change, :token_id, nil)
    #       end

    #     if updated_change.token_id do
    #       changes_list_with_token_id = [updated_change | acc.changes_list_with_token_id]

    #       %{
    #         changes_list_no_token_id: acc.changes_list_no_token_id,
    #         changes_list_with_token_id: changes_list_with_token_id
    #       }
    #     else
    #       changes_list_no_token_id = [updated_change | acc.changes_list_no_token_id]

    #       %{
    #         changes_list_no_token_id: changes_list_no_token_id,
    #         changes_list_with_token_id: acc.changes_list_with_token_id
    #       }
    #     end
    #   end)

    # ordered_changes_list_no_token_id =
    #   changes_list_no_token_id
    #   |> Enum.group_by(fn %{
    #                         address_hash: address_hash,
    #                         token_contract_address_hash: token_contract_address_hash,
    #                         block_number: block_number
    #                       } ->
    #     {token_contract_address_hash, address_hash, block_number}
    #   end)
    #   |> Enum.map(fn {_, grouped_address_token_balances} ->
    #     uniq = Enum.uniq(grouped_address_token_balances)

    #     if Enum.count(uniq) > 1 do
    #       Enum.max_by(uniq, fn %{value_fetched_at: value_fetched_at} -> value_fetched_at end)
    #     else
    #       Enum.at(uniq, 0)
    #     end
    #   end)
    #   |> Enum.sort_by(&{&1.token_contract_address_hash, &1.address_hash, &1.block_number})

    # ordered_changes_list_with_token_id =
    #   changes_list_with_token_id
    #   |> Enum.group_by(fn %{
    #                         address_hash: address_hash,
    #                         token_contract_address_hash: token_contract_address_hash,
    #                         token_id: token_id,
    #                         block_number: block_number
    #                       } ->
    #     {token_contract_address_hash, token_id, address_hash, block_number}
    #   end)
    #   |> Enum.map(fn {_, grouped_address_token_balances} ->
    #     if Enum.count(grouped_address_token_balances) > 1 do
    #       Enum.max_by(grouped_address_token_balances, fn %{value_fetched_at: value_fetched_at} -> value_fetched_at end)
    #     else
    #       Enum.at(grouped_address_token_balances, 0)
    #     end
    #   end)
    #   |> Enum.sort_by(&{&1.token_contract_address_hash, &1.token_id, &1.address_hash, &1.block_number})

    # {:ok, inserted_changes_list_no_token_id} =
    #   if Enum.count(ordered_changes_list_no_token_id) > 0 do
    #     Import.insert_changes_list(
    #       repo,
    #       ordered_changes_list_no_token_id,
    #       conflict_target:
    #         {:unsafe_fragment, ~s<(address_hash, token_contract_address_hash, block_number) WHERE token_id IS NULL>},
    #       on_conflict: on_conflict,
    #       for: TokenBalance,
    #       returning: true,
    #       timeout: timeout,
    #       timestamps: timestamps
    #     )
    #   else
    #     {:ok, []}
    #   end

    # {:ok, inserted_changes_list_with_token_id} =
    #   if Enum.count(ordered_changes_list_with_token_id) > 0 do
    #     Import.insert_changes_list(
    #       repo,
    #       ordered_changes_list_with_token_id,
    #       conflict_target:
    #         {:unsafe_fragment,
    #          ~s<(address_hash, token_contract_address_hash, token_id, block_number) WHERE token_id IS NOT NULL>},
    #       on_conflict: on_conflict,
    #       for: TokenBalance,
    #       returning: true,
    #       timeout: timeout,
    #       timestamps: timestamps
    #     )
    #   else
    #     {:ok, []}
    #   end

    # inserted_changes_list = inserted_changes_list_no_token_id ++ inserted_changes_list_with_token_id

    # Logger.info(" ### Address_token_balances insert FINISHED ###")
    # {:ok, inserted_changes_list}
  end

  defp default_on_conflict do
    from(
      token_balance in TokenBalance,
      update: [
        set: [
          value: fragment("EXCLUDED.value"),
          value_fetched_at: fragment("EXCLUDED.value_fetched_at"),
          token_type: fragment("EXCLUDED.token_type"),
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
