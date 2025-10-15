defmodule Indexer.Fetcher.Zilliqa.Zrc2Tokens do
  @moduledoc """
  Fills `zrc2_token_transfers` (or `token_transfers` along with `tokens` DB tables) and `zrc2_token_adapters` table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query
  import Explorer.Helper, only: [decode_data: 2]

  import Indexer.Block.Fetcher,
    only: [
      async_import_token_balances: 2,
      async_import_tokens: 2
    ]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, Data, Hash, Log, SmartContract, TokenTransfer, Transaction}
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
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
    :ignore
    #{:ok, %{}, {:continue, nil}}
  end

  @impl GenServer
  def handle_continue(_, state) do
    Logger.metadata(fetcher: __MODULE__)

    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    :timer.sleep(2000)

    block_number_to_analyze =
      case LastFetchedCounter.get(@counter_type, nullable: true) do
        nil -> last_known_block_number()
        block_number -> Decimal.to_integer(block_number)
      end

    if is_nil(block_number_to_analyze) do
      Logger.warning("There are no known consensus blocks in the database, so #{__MODULE__} won't start.")
      {:stop, :normal, state}
    else
      first_block_number = Application.get_env(:indexer, :first_block)
      Process.send(self(), :continue, [])

      {:noreply,
       %{
         block_number_to_analyze: block_number_to_analyze,
         is_initial_block: true,
         first_block_number: first_block_number
       }}
    end
  end

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
            "Handling blocks #{block_number_to_analyze}..#{div(block_number_to_analyze, @logging_max_block_range) * @logging_max_block_range + 1}..."
          )

        rem(block_number_to_analyze, @logging_max_block_range) == 0 ->
          Logger.info(
            "Handling blocks #{block_number_to_analyze}..#{block_number_to_analyze - @logging_max_block_range + 1}..."
          )

        true ->
          :ok
      end

      logs = read_block_logs(block_number_to_analyze)
      transactions = read_transfer_transactions(logs)

      block_numbers_to_analyze = Range.new(block_number_to_analyze, block_number_to_analyze)

      fetch_zrc2_token_transfers_and_adapters(logs, transactions, block_numbers_to_analyze, __MODULE__)
      move_zrc2_token_transfers_to_token_transfers()

      LastFetchedCounter.upsert(%{
        counter_type: @counter_type,
        value: block_number_to_analyze - 1
      })

      # little pause to unload cpu
      Process.send_after(self(), :continue, 10)
    else
      move_zrc2_token_transfers_to_token_transfers()
      Process.send_after(self(), :continue, :timer.seconds(10))
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
    zrc2_logs =
      Enum.filter(
        logs,
        &(Hash.to_string(&1.first_topic) in [
            @zrc2_transfer_success_event,
            @zrc2_transfer_from_success_event,
            @zrc2_minted_event,
            @zrc2_burnt_event
          ])
      )

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
            # the adapter address is unknown yet, so place the token transfer to the `zrc2_token_transfers` table
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
        zrc2_token_transfers: zrc2_token_transfers
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
        zrc2_token_transfers: %{params: zrc2_token_transfers},
        timeout: :infinity
      })

    async_import_tokens(imported, calling_module == Indexer.Block.Realtime.Fetcher)
    async_import_token_balances(imported, calling_module == Indexer.Block.Realtime.Fetcher)

    fetch_zrc2_token_adapters(logs, transactions, block_numbers, adapter_address_hash_by_zrc2_address_hash, calling_module)
  end

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
  defp fetch_zrc2_token_adapters(logs, transactions, block_numbers, adapter_address_hash_by_zrc2_address_hash, calling_module) do
    transaction_by_hash =
      transactions
      |> Enum.map(&{&1.hash, &1})
      |> Enum.into(%{})

    zrc2_token_adapters =
      logs
      |> Enum.filter(fn log ->
        with true <- Hash.to_string(log.first_topic) == @zrc2_transfer_success_event,
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
            &(Hash.to_string(&1.first_topic) == TokenTransfer.constant() and &1.address_hash == to_address_hash)
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
          addresses: %{params: Addresses.extract_addresses(%{zrc2_token_adapters: zrc2_token_adapters})},
          zrc2_token_adapters: %{params: zrc2_token_adapters},
          timeout: :infinity
        })
    end
  end

  @spec move_zrc2_token_transfers_to_token_transfers() :: :ok
  defp move_zrc2_token_transfers_to_token_transfers do
    query =
      from(
        ztt in Zrc2TokenTransfer,
        inner_join: a in TokenAdapter,
        on: a.zrc2_address_hash == ztt.zrc2_address_hash,
        select: %{
          transaction_hash: ztt.transaction_hash,
          log_index: ztt.log_index,
          from_address_hash: ztt.from_address_hash,
          to_address_hash: ztt.to_address_hash,
          amount: ztt.amount,
          adapter_address_hash: a.adapter_address_hash,
          block_number: ztt.block_number,
          block_hash: ztt.block_hash
        }
      )

    token_transfers =
      query
      |> Repo.all(timeout: :infinity)
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

  @spec read_block_logs(non_neg_integer()) :: [
          %{
            first_topic: Hash.t(),
            data: Data.t(),
            address_hash: Hash.t(),
            transaction_hash: Hash.t(),
            index: non_neg_integer(),
            block_number: non_neg_integer(),
            block_hash: Hash.t(),
            adapter_address_hash: Hash.t() | nil
          }
        ]
  defp read_block_logs(block_number) do
    transfer_events = [
      @zrc2_transfer_success_event,
      @zrc2_transfer_from_success_event,
      @zrc2_minted_event,
      @zrc2_burnt_event,
      TokenTransfer.constant()
    ]

    Repo.all(
      from(
        l in Log,
        inner_join: b in Block,
        on: b.hash == l.block_hash and b.consensus == true,
        left_join: a in TokenAdapter,
        on: a.zrc2_address_hash == l.address_hash,
        where: l.block_number == ^block_number and l.first_topic in ^transfer_events,
        select: %{
          first_topic: l.first_topic,
          data: l.data,
          address_hash: l.address_hash,
          transaction_hash: l.transaction_hash,
          index: l.index,
          block_number: l.block_number,
          block_hash: l.block_hash,
          adapter_address_hash: a.adapter_address_hash
        }
      ),
      timeout: :infinity
    )
  end

  @spec read_transfer_transactions([
          %{first_topic: Hash.t(), transaction_hash: Hash.t(), adapter_address_hash: Hash.t() | nil}
        ]) :: [%{hash: Hash.t(), input: Data.t(), to_address_hash: Hash.t()}]
  defp read_transfer_transactions(logs) do
    transaction_hashes =
      logs
      |> Enum.filter(
        &(Hash.to_string(&1.first_topic) == @zrc2_transfer_success_event and is_nil(&1.adapter_address_hash))
      )
      |> Enum.map(& &1.transaction_hash)

    Repo.all(
      from(
        t in Transaction,
        where: t.hash in ^transaction_hashes,
        select: %{
          hash: t.hash,
          input: t.input,
          to_address_hash: t.to_address_hash
        }
      ),
      timeout: :infinity
    )
  end

  @spec last_known_block_number() :: non_neg_integer() | nil
  defp last_known_block_number do
    Repo.aggregate(Block.consensus_blocks_query(), :max, :number)
  end

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
