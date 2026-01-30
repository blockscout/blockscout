defmodule Indexer.Fetcher.Zilliqa.Zrc2Tokens do
  @moduledoc """
  Fills `zilliqa_zrc2_token_transfers` (or `token_transfers`) and `zilliqa_zrc2_token_adapters` table
  (with accompanying tables like `tokens`, `address_token_balances`, etc.).

  The `zilliqa_zrc2_token_transfers` table is used for temporary storing ZRC-2 transfers that have unknown adapter contract address.
  Once the token adapter address becomes known, the corresponding transfers are moved from
  the `zilliqa_zrc2_token_transfers` to `token_transfers` table (and the adapter address is used for the `token_contract_address_hash` field).

  This fetcher is responsible for:
  - handling historic ZRC-2 transfer events (`TransferSuccess`, `TransferFromSuccess`, `Minted`, `Burnt`) and
    filling the token transfer and token adapter tables.
  - periodically checking and moving ZRC-2 token transfers from the `zilliqa_zrc2_token_transfers`
    to the `token_transfers` table.

  Also, this fetcher contains a common handling function which is also called by the realtime and catchup block fetchers
  (see `fetch_zrc2_token_transfers_and_adapters` code) to handle the ZRC-2 transfer events in catchup and realtime mode.

  The historic handler goes through the `logs` and `transactions` database tables (in the reverse block number order)
  and fills the `zilliqa_zrc2_token_transfers` and `zilliqa_zrc2_token_adapters` tables. If ZRC-2 token adapter is already known
  (exists in the `zilliqa_zrc2_token_adapters` table), the fetcher instead writes the corresponding rows directly into the `token_transfers` table
  setting `token_contract_address_hash` field to the adapter's address.

  Periodically checking and moving ZRC-2 token transfers from the `zilliqa_zrc2_token_transfers` to the `token_transfers` table
  is implemented in the `move_zrc2_token_transfers_to_token_transfers` function. It's called after every
  `fetch_zrc2_token_transfers_and_adapters` call. After the historic handler finishes its work (reaches the FIRST_BLOCK),
  the `move_zrc2_token_transfers_to_token_transfers` function continues to be called periodically (once per a few seconds)
  to check and move token transfers created by the realtime (or catchup) block fetcher. This call isn't invoked in the block
  fetcher itself as it can take a lot of time (if there are a lot of rows in the `zilliqa_zrc2_token_transfers` table) and lead to
  block fetcher delays. It's called asynchronously by this fetcher instead.

  The handled token transfers are added with "ZRC-2" token type.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query
  import Explorer.Helper, only: [decode_data: 2]

  import Indexer.Block.Fetcher,
    only: [
      async_import_token_balances: 2,
      async_import_current_token_balances: 2,
      async_import_tokens: 2
    ]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.{Data, Hash, Log, SmartContract, TokenTransfer}
  alias Explorer.Chain.Zilliqa.Zrc2.TokenAdapter
  alias Explorer.Chain.Zilliqa.Zrc2.TokenTransfer, as: Zrc2TokenTransfer
  alias Indexer.Block.Fetcher, as: BlockFetcher
  alias Indexer.TokenBalances
  alias Indexer.Transform.{Addresses, AddressTokenBalances}

  @counter_type "zilliqa_zrc2_tokens_fetcher_last_block_number"
  @logging_max_block_range 100

  @zrc2_transfer_success_event "0xa5901fdb53ef45260c18811f35461e0eda2b6133d807dabbfb65314dd4fc2fac"
  @zrc2_transfer_from_success_event "0x96acecb2152edcc0681aa27d354d55d64192e86489ff8d5d903d63ef266755a1"
  @zrc2_minted_event "0x845020906442ad0651b44a75d9767153912bfa586416784cf8ead41b37b1dbf5"
  @zrc2_burnt_event "0x92b328e20a23b6dc6c50345c8a05b555446cbde2e9e1e2ee91dab47bd5204d07"

  @check_zrc2_token_transfers_interval :timer.seconds(10)

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(_args) do
    {:ok, %{}, {:continue, nil}}
  end

  @impl GenServer
  def handle_continue(_, _state) do
    Logger.metadata(fetcher: __MODULE__)

    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    :timer.sleep(2000)

    # get the starting block number from the cache to start from the same point
    # we stopped before the instance was down. If this is the first run,
    # get the latest known block number from the `logs` table
    block_number_to_analyze =
      case LastFetchedCounter.get(@counter_type, nullable: true) do
        nil -> Log.last_known_block_number()
        block_number -> Decimal.to_integer(block_number)
      end

    if is_nil(block_number_to_analyze) do
      # this is the first run of the instance from scratch, so the events will be handled by the realtime and catchup indexers
      # and we only need to call the `move_zrc2_token_transfers_to_token_transfers` periodically
      Logger.info(
        "There are no known consensus blocks in the database, so #{__MODULE__} will only periodically check the `zilliqa_zrc2_token_transfers` table."
      )

      LastFetchedCounter.upsert(%{counter_type: @counter_type, value: 0})
      Process.send_after(self(), :continue, @check_zrc2_token_transfers_interval)

      {:noreply, %{block_number_to_analyze: 0, is_initial_block: true, first_block_number: 0}}
    else
      # we continue handling after instance restart
      first_block_number =
        if block_number_to_analyze > 0 do
          max(Application.get_env(:indexer, :first_block), Log.first_known_block_number())
        else
          0
        end

      Process.send(self(), :continue, [])

      {:noreply,
       %{
         block_number_to_analyze: block_number_to_analyze,
         is_initial_block: true,
         first_block_number: first_block_number
       }}
    end
  end

  @doc """
  Implements the handler loop.

  If we didn't reach the FIRST_BLOCK, get the logs and transactions of the `block_number_to_analyze` block,
  call the `fetch_zrc2_token_transfers_and_adapters` function for this block, call the
  `move_zrc2_token_transfers_to_token_transfers` function, and go to the next block (in the reverse order).

  If we reached the FIRST_BLOCK, we just call the `move_zrc2_token_transfers_to_token_transfers` function
  and go to the next iteration (and so on indefinitely).

  ## Parameters
  - `:continue`: The GenServer message.
  - `%{:block_number_to_analyze, :is_initial_block, :first_block_number}`: A map with the current module state where:
    - `block_number_to_analyze` is the current block number we need to handle. Must be zero if we only need to call
      `move_zrc2_token_transfers_to_token_transfers`.
    - `is_initial_block` must be `true` for the first iteration (for correct logging).
    - `first_block_number` is the block number which should be processed last.

  ## Returns
  - `{:noreply, %{:block_number_to_analyze, :is_initial_block, :first_block_number}}` map with the changed state.
  """
  @impl GenServer
  def handle_info(:continue, %{
        block_number_to_analyze: block_number_to_analyze,
        is_initial_block: is_initial_block,
        first_block_number: first_block_number
      }) do
    if block_number_to_analyze > 0 and block_number_to_analyze >= first_block_number do
      cond do
        is_initial_block ->
          Logger.info(
            "Handling blocks #{block_number_to_analyze}..#{max(div(block_number_to_analyze, @logging_max_block_range) * @logging_max_block_range + 1, first_block_number)}..."
          )

        rem(block_number_to_analyze, @logging_max_block_range) == 0 ->
          Logger.info(
            "Handling blocks #{block_number_to_analyze}..#{max(block_number_to_analyze - @logging_max_block_range + 1, first_block_number)}..."
          )

        true ->
          :ok
      end

      transfer_events = [
        @zrc2_transfer_success_event,
        @zrc2_transfer_from_success_event,
        @zrc2_minted_event,
        @zrc2_burnt_event,
        TokenTransfer.constant()
      ]

      logs = Zrc2TokenTransfer.read_block_logs(block_number_to_analyze, transfer_events)
      transactions = Zrc2TokenTransfer.read_transfer_transactions(logs, @zrc2_transfer_success_event)

      block_numbers_to_analyze = Range.new(block_number_to_analyze, block_number_to_analyze)

      fetch_zrc2_token_transfers_and_adapters(logs, transactions, block_numbers_to_analyze, __MODULE__)
      move_zrc2_token_transfers_to_token_transfers()

      LastFetchedCounter.upsert(%{counter_type: @counter_type, value: block_number_to_analyze - 1})

      # little pause to unload cpu
      Process.send_after(self(), :continue, 10)
    else
      Logger.info("Checking zilliqa_zrc2_token_transfers table and hanging adapters...")
      move_zrc2_token_transfers_to_token_transfers()
      remove_hanging_adapters()
      Process.send_after(self(), :continue, @check_zrc2_token_transfers_interval)
    end

    {:noreply,
     %{
       block_number_to_analyze: max(block_number_to_analyze - 1, 0),
       is_initial_block: false,
       first_block_number: first_block_number
     }}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @doc """
  Fetches ZRC-2 token transfers and adapter contract addresses for ZRC-2 tokens
  by the given list of logs and transactions from a certain block range.

  ## Parameters
  - `logs`: The list of logs to filter them by ZRC-2 events.
  - `transactions`: The list of transactions to find ZRC-2 adapter addresses.
  - `block_numbers`: The block range for logging purposes.
  - `calling_module`: The calling module for logging purposes and for prioritization
                      of async import of tokens and balances.

  ## Returns
  - Nothing.
  """
  @spec fetch_zrc2_token_transfers_and_adapters(
          [
            %{
              :first_topic => Hash.t(),
              :data => Data.t(),
              :address_hash => Hash.t(),
              :transaction_hash => Hash.t(),
              :index => non_neg_integer(),
              :block_number => non_neg_integer(),
              :block_hash => Hash.t(),
              optional(:adapter_address_hash) => Hash.t() | nil
            }
          ],
          [
            %{
              :hash => Hash.t(),
              :input => Data.t(),
              :to_address_hash => Hash.t()
            }
          ],
          Range.t(),
          module()
        ) :: no_return()
  def fetch_zrc2_token_transfers_and_adapters([], _transactions, _block_numbers, _calling_module), do: nil

  def fetch_zrc2_token_transfers_and_adapters(logs, transactions, block_numbers, calling_module) do
    zrc2_logs = filter_zrc2_logs(logs)

    adapter_address_hash_by_zrc2_address_hash =
      zrc2_logs
      |> Enum.reject(&Map.has_key?(&1, :adapter_address_hash))
      |> Enum.map(& &1.address_hash)
      |> Enum.uniq()
      |> TokenAdapter.adapter_address_hash_by_zrc2_address_hash()

    {zrc2_token_transfers, token_transfers} =
      zrc2_logs
      |> Enum.reduce({[], []}, fn log, {zrc2_token_transfers_acc, token_transfers_acc} ->
        first_topic = Hash.to_string(log.first_topic)
        params = zrc2_event_params(log.data)

        {from_address_hash, to_address_hash, amount} =
          try do
            cond do
              first_topic in [@zrc2_transfer_success_event, @zrc2_transfer_from_success_event] ->
                {params.sender, params.recipient, Decimal.new(params.amount)}

              first_topic == @zrc2_minted_event ->
                {SmartContract.burn_address_hash_string(), params.recipient, Decimal.new(params.amount)}

              first_topic == @zrc2_burnt_event ->
                {params.burn_account, SmartContract.burn_address_hash_string(), Decimal.new(params.amount)}
            end
          rescue
            _ ->
              {nil, nil, nil}
          end

        if Enum.all?([from_address_hash, to_address_hash, amount], &is_nil(&1)) do
          # the event is not supported as has incorrect parameters (doesn't relate to ZRC-2)
          {zrc2_token_transfers_acc, token_transfers_acc}
        else
          adapter_address_hash = zrc2_log_adapter_address_hash(log, adapter_address_hash_by_zrc2_address_hash)

          token_transfer = %{
            transaction_hash: log.transaction_hash,
            log_index: log.index,
            from_address_hash: from_address_hash,
            to_address_hash: to_address_hash,
            amount: amount,
            block_number: log.block_number,
            block_hash: log.block_hash
          }

          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          if is_nil(adapter_address_hash) do
            # the adapter address is unknown yet, so place the token transfer to the `zilliqa_zrc2_token_transfers` table
            {[Map.put(token_transfer, :zrc2_address_hash, Hash.to_string(log.address_hash)) | zrc2_token_transfers_acc],
             token_transfers_acc}
          else
            # the adapter address is already known, so place the token transfer directly to the `token_transfers` table
            {zrc2_token_transfers_acc,
             [
               token_transfer
               |> Map.put(:token_contract_address_hash, Hash.to_string(adapter_address_hash))
               |> Map.put(:token_type, "ZRC-2")
               |> Map.put(:block_consensus, true)
               |> Map.put(:token_ids, nil)
               | token_transfers_acc
             ]}
          end
        end
      end)

    if token_transfers != [] do
      Logger.info(
        "Found #{Enum.count(token_transfers)} ZRC-2 token transfer(s) with known adapter address in the block(s) #{block_range_printable(block_numbers)}.",
        fetcher: calling_module
      )
    end

    if zrc2_token_transfers != [] do
      Logger.info(
        "Found #{Enum.count(zrc2_token_transfers)} ZRC-2 token transfer(s) with unknown adapter address in the block(s) #{block_range_printable(block_numbers)}.",
        fetcher: calling_module
      )
    end

    addresses =
      Addresses.extract_addresses(%{
        token_transfers: token_transfers,
        zilliqa_zrc2_token_transfers: zrc2_token_transfers
      })

    {tokens, address_token_balances, address_current_token_balances} =
      prepare_tokens_and_balances(token_transfers)

    {:ok, imported} =
      Chain.import(%{
        addresses: %{params: addresses},
        address_token_balances: %{params: address_token_balances},
        address_current_token_balances: %{params: address_current_token_balances},
        tokens: %{params: tokens},
        token_transfers: %{params: token_transfers},
        zilliqa_zrc2_token_transfers: %{params: zrc2_token_transfers},
        timeout: :infinity
      })

    async_import_tokens(imported, calling_module == Indexer.Block.Realtime.Fetcher)
    async_import_token_balances(imported, calling_module == Indexer.Block.Realtime.Fetcher)
    async_import_current_token_balances(imported, calling_module == Indexer.Block.Realtime.Fetcher)

    fetch_zrc2_token_adapters(
      logs,
      transactions,
      block_numbers,
      adapter_address_hash_by_zrc2_address_hash,
      calling_module
    )
  end

  # Filters the given logs to get ZRC-2 logs.
  #
  # ## Parameters
  # - `logs`: The unfiltered list of logs.
  #
  # ## Returns
  # - The filtered list of logs.
  @spec filter_zrc2_logs(list()) :: list()
  defp filter_zrc2_logs(logs) do
    logs
    |> Enum.filter(
      &(!is_nil(&1.first_topic) and
          Hash.to_string(&1.first_topic) in [
            @zrc2_transfer_success_event,
            @zrc2_transfer_from_success_event,
            @zrc2_minted_event,
            @zrc2_burnt_event
          ])
    )
  end

  # Fetches ZRC-2 token adapter contract addresses for ZRC-2 tokens
  # by the given list of logs and transactions from a certain block range.
  #
  # For `TransferSuccess` event, we look into the corresponding transaction input: if that's the `transfer` method call
  # and the transaction doesn't have the corresponding `Transfer` event emitted by the `to` address, the `to` address
  # is the adapter address we searching for, and the address emitted the `TransferSuccess` event is the corresponding
  # ZRC-2 address.
  #
  # ## Parameters
  # - `logs`: The list of logs to filter them by `TransferSuccess` and `Transfer` events.
  # - `transactions`: The list of transactions to find ZRC-2 adapter addresses.
  # - `block_numbers`: The block range for logging purposes.
  # - `adapter_address_hash_by_zrc2_address_hash`: A `%{zrc2_address_hash => adapter_address_hash}` map with
  #   the existing relations to avoid searching of already found adapter addresses.
  # - `calling_module`: The calling module for logging purposes.
  #
  # ## Returns
  # - Nothing.
  @spec fetch_zrc2_token_adapters(
          [
            %{
              :first_topic => Hash.t(),
              :data => Data.t(),
              :address_hash => Hash.t(),
              :transaction_hash => Hash.t(),
              :index => non_neg_integer(),
              :block_number => non_neg_integer(),
              :block_hash => Hash.t(),
              optional(:adapter_address_hash) => Hash.t() | nil
            }
          ],
          [
            %{
              :hash => Hash.t(),
              :input => Data.t(),
              :to_address_hash => Hash.t()
            }
          ],
          Range.t(),
          %{Hash.t() => Hash.t()},
          module()
        ) :: no_return()
  defp fetch_zrc2_token_adapters(
         logs,
         transactions,
         block_numbers,
         adapter_address_hash_by_zrc2_address_hash,
         calling_module
       ) do
    transaction_by_hash =
      transactions
      |> Enum.map(&{&1.hash, &1})
      |> Enum.into(%{})

    zrc2_token_adapters =
      logs
      |> Enum.filter(fn log ->
        with false <- is_nil(log.first_topic),
             true <- Hash.to_string(log.first_topic) == @zrc2_transfer_success_event,
             # only ZRC-2 is supported
             params = zrc2_event_params(log.data),
             true <- Map.has_key?(params, :sender) && Map.has_key?(params, :recipient) && Map.has_key?(params, :amount),
             true <- is_nil(zrc2_log_adapter_address_hash(log, adapter_address_hash_by_zrc2_address_hash)) do
          transaction_input = transaction_by_hash[log.transaction_hash].input.bytes

          method_id =
            if byte_size(transaction_input) >= 4 do
              <<method_id::binary-size(4), _::binary>> = transaction_input
              "0x" <> Base.encode16(method_id, case: :lower)
            end

          method_id == TokenTransfer.transfer_function_signature()
        else
          _ -> false
        end
      end)
      |> Enum.reduce([], fn log, acc ->
        transaction_hash = log.transaction_hash
        to_address_hash = transaction_by_hash[transaction_hash].to_address_hash

        # are there any `Transfer` logs emitted by the `to_address_hash` in this transaction?
        erc20_transfer_event_found =
          logs
          |> Enum.filter(&(&1.transaction_hash == transaction_hash))
          |> Enum.any?(
            &(!is_nil(&1.first_topic) and Hash.to_string(&1.first_topic) == TokenTransfer.constant() and
                &1.address_hash == to_address_hash)
          )

        if erc20_transfer_event_found do
          acc
        else
          # if the `Transfer` log is not found, this is ERC-20 adapter contract address
          [
            %{
              adapter_address_hash: Hash.to_string(to_address_hash),
              zrc2_address_hash: Hash.to_string(log.address_hash)
            }
            | acc
          ]
        end
      end)
      |> Enum.uniq()

    if zrc2_token_adapters != [] do
      Logger.info(
        "Found #{Enum.count(zrc2_token_adapters)} new ERC-20 adapter(s) for ZRC-2 token(s) in the block(s) #{block_range_printable(block_numbers)}.",
        fetcher: calling_module
      )

      {:ok, _} =
        Chain.import(%{
          addresses: %{params: Addresses.extract_addresses(%{zilliqa_zrc2_token_adapters: zrc2_token_adapters})},
          zilliqa_zrc2_token_adapters: %{params: zrc2_token_adapters},
          timeout: :infinity
        })
    end
  end

  # Scans the `zilliqa_zrc2_token_transfers` table for the rows that have corresponding
  # adapter addresses in the `zilliqa_zrc2_token_adapters` table. The found rows are inserted into the `token_transfers`
  # table (with the `token_contract_address_hash` == `adapter_address_hash` and `token_type` == "ZRC-2"), and then
  # removed from the `zilliqa_zrc2_token_transfers` table.
  #
  # For the found token transfers, the function prepares and asynchronously imports the corresponding tokens
  # and their balances.
  #
  # ## Returns
  # - :ok
  @spec move_zrc2_token_transfers_to_token_transfers() :: :ok
  defp move_zrc2_token_transfers_to_token_transfers do
    zrc2_token_transfers = Zrc2TokenTransfer.zrc2_token_transfers_having_adapter()

    token_transfers =
      zrc2_token_transfers
      |> Enum.map(fn token_transfer ->
        token_transfer
        |> Map.put(:from_address_hash, Hash.to_string(token_transfer.from_address_hash))
        |> Map.put(:to_address_hash, Hash.to_string(token_transfer.to_address_hash))
        |> Map.put(:token_contract_address_hash, Hash.to_string(token_transfer.adapter_address_hash))
        |> Map.put(:token_type, "ZRC-2")
        |> Map.put(:block_consensus, true)
        |> Map.put(:token_ids, nil)
        |> Map.delete(:adapter_address_hash)
      end)

    if token_transfers != [] do
      {tokens, address_token_balances, address_current_token_balances} =
        prepare_tokens_and_balances(token_transfers)

      Logger.info("Moving #{Enum.count(token_transfers)} ZRC-2 token transfer(s) to the token_transfers table...")

      {:ok, imported} =
        Chain.import(%{
          address_token_balances: %{params: address_token_balances},
          address_current_token_balances: %{params: address_current_token_balances},
          tokens: %{params: tokens},
          token_transfers: %{params: token_transfers},
          timeout: :infinity
        })

      async_import_tokens(imported, false)
      async_import_token_balances(imported, false)
      async_import_current_token_balances(imported, false)
    end

    Enum.each(token_transfers, fn tt ->
      Repo.delete_all(
        from(
          ztt in Zrc2TokenTransfer,
          where:
            ztt.transaction_hash == ^tt.transaction_hash and ztt.log_index == ^tt.log_index and
              ztt.block_hash == ^tt.block_hash
        )
      )
    end)
  end

  # Checks if there are adapter addresses not bound to any consensus token transfers: if there are,
  # they are removed from the `zilliqa_zrc2_token_adapters` table. Also, the corresponding rows are
  # removed from the `zilliqa_zrc2_token_transfers` table by the `zrc2_address_hash` address.
  # The hanging adapters can appear due to reorgs.
  @spec remove_hanging_adapters() :: any()
  defp remove_hanging_adapters do
    hanging_adapters =
      TokenAdapter
      |> Repo.all()
      |> Enum.reduce([], fn adapter, acc ->
        query =
          from(tt in TokenTransfer,
            where: tt.token_contract_address_hash == ^adapter.adapter_address_hash and tt.block_consensus == true,
            limit: 1
          )

        case Repo.one(query) do
          nil -> [adapter | acc]
          _ -> acc
        end
      end)

    if hanging_adapters != [] do
      adapter_address_hashes =
        hanging_adapters
        |> Enum.map(& &1.adapter_address_hash)

      zrc2_address_hashes =
        hanging_adapters
        |> Enum.map(& &1.zrc2_address_hash)

      Repo.delete_all(from(a in TokenAdapter, where: a.adapter_address_hash in ^adapter_address_hashes))
      Repo.delete_all(from(ztt in Zrc2TokenTransfer, where: ztt.zrc2_address_hash in ^zrc2_address_hashes))
    end
  end

  # Prepares tokens, token balances, and current token balances to be imported
  # to the database by the given token transfers.
  #
  # ## Parameters
  # - `token_transfers`: The list of token transfers details.
  #
  # ## Returns
  # - `{tokens, address_token_balances, address_current_token_balances}` tuple with the lists
  #   ready to be imported to the database.
  @spec prepare_tokens_and_balances([map()]) :: {list(), list(), list()}
  defp prepare_tokens_and_balances(token_transfers) do
    tokens =
      token_transfers
      |> Enum.map(&%{contract_address_hash: &1.token_contract_address_hash, type: &1.token_type})
      |> Enum.uniq()

    address_token_balances =
      %{token_transfers_params: BlockFetcher.token_transfers_merge_token(token_transfers, tokens)}
      |> AddressTokenBalances.params_set()
      |> MapSet.to_list()

    address_current_token_balances =
      address_token_balances
      |> TokenBalances.to_address_current_token_balances()

    {tokens, address_token_balances, address_current_token_balances}
  end

  # Gets ZRC-2 adapter address hash from the corresponding ZRC-2 log
  # or (if not found) from the `%{zrc2_address_hash => adapter_address_hash}` map.
  #
  # ## Parameters
  # - `log`: The ZRC-2 log map with or without the `adapter_address_hash` key.
  # - `adapter_address_hash_by_zrc2_address_hash`: The `%{zrc2_address_hash => adapter_address_hash}` map
  #   with already existing relations.
  #
  # ## Returns
  # - The adapter address hash.
  # - `nil` if not found.
  @spec zrc2_log_adapter_address_hash(
          %{optional(:adapter_address_hash) => Hash.t() | nil, :address_hash => Hash.t()},
          %{Hash.t() => Hash.t()}
        ) :: Hash.t() | nil
  defp zrc2_log_adapter_address_hash(log, adapter_address_hash_by_zrc2_address_hash) do
    case Map.fetch(log, :adapter_address_hash) do
      {:ok, adapter_address_hash} -> adapter_address_hash
      :error -> Map.get(adapter_address_hash_by_zrc2_address_hash, log.address_hash)
    end
  end

  # Converts ZRC-2 event string parameter into a map.
  #
  # Example:
  #   {"address":"0x818ca2e217e060ad17b7bd0124a483a1f66930a9","_eventname":"TransferSuccess","params":[{"vname":"sender","value":"0x90696d5bea3f11feb2e304718d17564d90c3d780","type":"ByStr20"},{"vname":"recipient","value":"0x4afc249b706560766a3c6ab8db2825102aa224fc","type":"ByStr20"},{"vname":"amount","value":"1000000000","type":"Uint128"}]}
  # will be converted to
  #   %{sender: "0x90696d5bea3f11feb2e304718d17564d90c3d780", recipient: "0x4afc249b706560766a3c6ab8db2825102aa224fc", amount: "1000000000"}
  #
  # ## Parameters
  # - `log_data`: The event's data field.
  #
  # ## Returns
  # - A map with the parameters from the event.
  @spec zrc2_event_params(Data.t()) :: map()
  defp zrc2_event_params(log_data) do
    log_data
    |> decode_data([:string])
    |> Enum.at(0)
    |> Jason.decode!()
    |> Map.get("params", nil)
    |> Enum.map(fn param -> {String.to_atom(param["vname"]), param["value"]} end)
    |> Enum.into(%{})
  end

  # Makes the given range human readable (and prints only one value if the range contains only one item).
  #
  # ## Parameters
  # - `range`: The range to make printable.
  #
  # ## Returns
  # - A string of the range.
  @spec block_range_printable(Range.t()) :: String.t()
  defp block_range_printable(range) do
    first..last//_step = range

    if Range.size(range) == 1 do
      to_string(first)
    else
      "#{first}..#{last}"
    end
  end
end
