defmodule Explorer.Chain.Import.Runner.Addresses do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Multi, Repo}
  alias Explorer.Chain.{Address, Hash, Import, Transaction}
  alias Explorer.Chain.Import.Runner

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  @row_defaults %{
    decompiled: false,
    verified: false
  }

  # milliseconds
  @timeout 60_000

  @type imported :: [Address.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Address

  @impl Import.Runner
  def option_key, do: :addresses

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

    transactions_timeout = options[Runner.Transactions.option_key()][:timeout] || Runner.Transactions.timeout()

    update_transactions_options = %{timeout: transactions_timeout, timestamps: timestamps}

    changes_list_with_defaults =
      Enum.map(changes_list, fn change ->
        Enum.reduce(@row_defaults, change, fn {default_key, default_value}, acc ->
          Map.put_new(acc, default_key, default_value)
        end)
      end)

    multi
    |> Multi.run(:addresses, fn repo, _ ->
      insert(repo, changes_list_with_defaults, insert_options)
    end)
    |> Multi.run(:created_address_code_indexed_at_transactions, fn repo, %{addresses: addresses}
                                                                   when is_list(addresses) ->
      update_transactions(repo, addresses, update_transactions_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  ## Private Functions

  @spec insert(Repo.t(), [%{hash: Hash.Address.t()}], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Address.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce Address ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list =
      changes_list
      |> Enum.group_by(fn %{
                            hash: hash
                          } ->
        {hash}
      end)
      |> Enum.map(fn {_, grouped_addresses} ->
        Enum.max_by(grouped_addresses, fn address ->
          address_max_by(address)
        end)
      end)
      |> Enum.sort_by(& &1.hash)

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: :hash,
      on_conflict: on_conflict,
      for: Address,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )
  end

  defp address_max_by(address) do
    cond do
      Map.has_key?(address, :address) ->
        address.fetched_coin_balance_block_number

      Map.has_key?(address, :nonce) ->
        address.nonce

      true ->
        address
    end
  end

  defp default_on_conflict do
    from(address in Address,
      update: [
        set: [
          contract_code: fragment("COALESCE(EXCLUDED.contract_code, ?)", address.contract_code),
          # ARGMAX on two columns
          fetched_coin_balance:
            fragment(
              """
              CASE WHEN EXCLUDED.fetched_coin_balance_block_number IS NOT NULL
                    AND EXCLUDED.fetched_coin_balance IS NOT NULL AND
                        (? IS NULL OR ? IS NULL OR
                         EXCLUDED.fetched_coin_balance_block_number >= ?) THEN
                          EXCLUDED.fetched_coin_balance
                   ELSE ?
              END
              """,
              address.fetched_coin_balance,
              address.fetched_coin_balance_block_number,
              address.fetched_coin_balance_block_number,
              address.fetched_coin_balance
            ),
          # MAX on two columns
          fetched_coin_balance_block_number:
            fragment(
              "GREATEST(EXCLUDED.fetched_coin_balance_block_number, ?)",
              address.fetched_coin_balance_block_number
            ),
          nonce: fragment("GREATEST(EXCLUDED.nonce, ?)", address.nonce),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", address.updated_at)
        ]
      ],
      # where any of `set`s would make a change
      # This is so that tuples are only generated when a change would occur
      where:
        fragment("COALESCE(?, EXCLUDED.contract_code) IS DISTINCT FROM ?", address.contract_code, address.contract_code) or
          fragment(
            "EXCLUDED.fetched_coin_balance_block_number IS NOT NULL AND (? IS NULL OR EXCLUDED.fetched_coin_balance_block_number >= ?)",
            address.fetched_coin_balance_block_number,
            address.fetched_coin_balance_block_number
          ) or fragment("GREATEST(?, EXCLUDED.nonce) IS DISTINCT FROM  ?", address.nonce, address.nonce)
    )
  end

  defp update_transactions(repo, addresses, %{timeout: timeout, timestamps: timestamps}) do
    ordered_created_contract_hashes =
      addresses
      |> Enum.filter(& &1.contract_code)
      |> MapSet.new(& &1.hash)
      |> Enum.sort()

    if Enum.empty?(ordered_created_contract_hashes) do
      {:ok, []}
    else
      query =
        from(t in Transaction,
          where: t.created_contract_address_hash in ^ordered_created_contract_hashes,
          # Enforce Transaction ShareLocks order (see docs: sharelocks.md)
          order_by: t.hash,
          lock: "FOR UPDATE"
        )

      try do
        {_, result} =
          repo.update_all(
            from(t in Transaction, join: s in subquery(query), on: t.hash == s.hash),
            [set: [created_contract_code_indexed_at: timestamps.updated_at]],
            timeout: timeout
          )

        {:ok, result}
      rescue
        postgrex_error in Postgrex.Error ->
          {:error, %{exception: postgrex_error, transaction_hashes: ordered_created_contract_hashes}}
      end
    end
  end
end
