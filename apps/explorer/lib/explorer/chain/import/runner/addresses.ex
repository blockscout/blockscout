defmodule Explorer.Chain.Import.Runner.Addresses do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.t/0`.
  """

  import Ecto.Query, only: [from: 2]
  import Explorer.Chain.Import.Runner.Helper, only: [chain_type_dependent_import: 3]

  alias Ecto.{Multi, Repo}
  alias Explorer.Chain.Filecoin.PendingAddressOperation, as: FilecoinPendingAddressOperation
  alias Explorer.Chain.Import.Runner
  alias Explorer.Chain.{Address, Import, Transaction}
  alias Explorer.Prometheus.Instrumenter

  require Ecto.Query

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

    ordered_changes_list =
      changes_list_with_defaults
      |> Enum.group_by(& &1.hash)
      |> Enum.map(fn {_, grouped_addresses} ->
        Enum.max_by(grouped_addresses, fn address ->
          address_max_by(address)
        end)
      end)
      |> Enum.sort_by(& &1.hash)

    multi
    |> Multi.run(:filter_addresses, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> filter_addresses(repo, ordered_changes_list, options[option_key()][:fields_to_update]) end,
        :addresses,
        :addresses,
        :filter_addresses
      )
    end)
    |> Multi.run(:addresses, fn repo, %{filter_addresses: {addresses, _existing_addresses}} ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, addresses, insert_options) end,
        :addresses,
        :addresses,
        :addresses
      )
    end)
    |> Multi.run(:created_address_code_indexed_at_transactions, fn repo,
                                                                   %{
                                                                     addresses: addresses,
                                                                     filter_addresses: {_, existing_addresses_map}
                                                                   }
                                                                   when is_list(addresses) ->
      Instrumenter.block_import_stage_runner(
        fn -> update_transactions(repo, addresses, existing_addresses_map, update_transactions_options) end,
        :addresses,
        :addresses,
        :created_address_code_indexed_at_transactions
      )
    end)
    |> chain_type_dependent_import(
      :filecoin,
      &Multi.run(
        &1,
        :filecoin_pending_address_operations,
        fn repo, _ ->
          Instrumenter.block_import_stage_runner(
            fn -> filecoin_pending_address_operations(repo, ordered_changes_list, insert_options) end,
            :addresses,
            :addresses,
            :filecoin_pending_address_operations
          )
        end
      )
    )
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @impl Import.Runner
  def runner_specific_options, do: [:fields_to_update]

  ## Private Functions

  @spec filter_addresses(Repo.t(), [map()], [atom()] | nil) :: {:ok, {[map()], map()}}
  defp filter_addresses(repo, changes_list, fields_to_update) do
    hashes = Enum.map(changes_list, & &1.hash)

    existing_addresses_query =
      from(a in Address,
        where: a.hash in ^hashes,
        select: [:hash, :contract_code, :fetched_coin_balance_block_number, :nonce]
      )

    existing_addresses_map =
      existing_addresses_query
      |> repo.all()
      |> Map.new(&{&1.hash, &1})

    filtered_addresses =
      changes_list
      |> Enum.reduce([], fn address, acc ->
        existing_address = existing_addresses_map[address.hash]

        if should_update?(address, existing_address, fields_to_update) do
          [address | acc]
        else
          acc
        end
      end)
      |> Enum.reverse()

    {:ok, {filtered_addresses, existing_addresses_map}}
  end

  defp should_update?(_new_address, nil, _fields_to_replace), do: true

  defp should_update?(new_address, existing_address, nil) do
    (not is_nil(new_address[:contract_code]) and new_address[:contract_code] != existing_address.contract_code) or
      (not is_nil(new_address[:fetched_coin_balance_block_number]) and
         (is_nil(existing_address.fetched_coin_balance_block_number) or
            new_address[:fetched_coin_balance_block_number] >= existing_address.fetched_coin_balance_block_number)) or
      (not is_nil(new_address[:nonce]) and
         (is_nil(existing_address.nonce) or new_address[:nonce] > existing_address.nonce))
  end

  defp should_update?(new_address, existing_address, fields_to_replace) do
    fields_to_replace
    |> Enum.any?(fn field -> Map.get(existing_address, field) != Map.get(new_address, field) end)
  end

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Address.t()]}
  def insert(repo, ordered_changes_list, %{timeout: timeout, timestamps: timestamps} = options)
      when is_list(ordered_changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

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
        fragment("COALESCE(EXCLUDED.contract_code, ?) IS DISTINCT FROM ?", address.contract_code, address.contract_code) or
          fragment(
            "EXCLUDED.fetched_coin_balance_block_number IS NOT NULL AND (? IS NULL OR EXCLUDED.fetched_coin_balance_block_number >= ?)",
            address.fetched_coin_balance_block_number,
            address.fetched_coin_balance_block_number
          ) or fragment("GREATEST(?, EXCLUDED.nonce) IS DISTINCT FROM  ?", address.nonce, address.nonce)
    )
  end

  defp update_transactions(repo, addresses, existing_addresses_map, %{timeout: timeout, timestamps: timestamps}) do
    ordered_created_contract_hashes =
      addresses
      |> Enum.filter(fn address ->
        existing_address = existing_addresses_map[address.hash]

        not is_nil(address.contract_code) and (is_nil(existing_address) or is_nil(existing_address.contract_code))
      end)
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
          lock: "FOR NO KEY UPDATE"
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

  defp filecoin_pending_address_operations(repo, addresses, %{timeout: timeout, timestamps: timestamps}) do
    ordered_addresses =
      addresses
      |> Enum.map(
        &%{
          address_hash: &1.hash,
          refetch_after: nil
        }
      )
      |> Enum.sort_by(& &1.address_hash)
      |> Enum.dedup_by(& &1.address_hash)

    Import.insert_changes_list(
      repo,
      ordered_addresses,
      conflict_target: :address_hash,
      on_conflict: :nothing,
      for: FilecoinPendingAddressOperation,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )
  end
end
