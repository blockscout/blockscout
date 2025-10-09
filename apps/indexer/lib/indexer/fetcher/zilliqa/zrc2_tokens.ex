defmodule Indexer.Fetcher.Zilliqa.Zrc2Tokens do
  @moduledoc """
  Fills `zrc2_token_transfers` (or `token_transfers` along with `tokens` DB tables) and `zrc2_token_adapters` table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query
  import Explorer.Helper, only: [decode_data: 2]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, Data, Hash, Log, SmartContract, TokenTransfer, Transaction}
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.Zilliqa.Zrc2.TokenAdapter

  @fetcher_name :zilliqa_zrc2_tokens
  @counter_type "zilliqa_zrc2_tokens_fetcher_last_block_number"

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
    {:ok, %{}, {:continue, nil}}
  end

  @impl GenServer
  def handle_continue(_, state) do
    Logger.metadata(fetcher: @fetcher_name)

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
      Process.send(self(), :continue, [])
      {:noreply, %{block_number_to_analyze: block_number_to_analyze}}
    end
  end

  @impl GenServer
  def handle_info(:continue, %{block_number_to_analyze: block_number_to_analyze}) do
    if block_number_to_analyze > 0 do
      logs = read_block_logs(block_number_to_analyze)
      transactions = read_transfer_transactions(logs)

      fetch_zrc2_token_transfers_and_adapters(logs, transactions)
      # move_zrc2_token_transfers_to_token_transfers()

      LastFetchedCounter.upsert(%{
        counter_type: @counter_type,
        value: block_number_to_analyze - 1
      })

      Process.send(self(), :continue, [])
    else
      # move_zrc2_token_transfers_to_token_transfers()
      Process.send_after(self(), :continue, :timer.seconds(10))
    end

    {:noreply, %{block_number_to_analyze: max(block_number_to_analyze - 1, 0)}}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  def fetch_zrc2_token_transfers_and_adapters(logs, _transactions) do
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
          cond do
            first_topic in [@zrc2_transfer_success_event, @zrc2_transfer_from_success_event] ->
              {params.sender, params.recipient, Decimal.new(params.amount)}

            first_topic == @zrc2_minted_event ->
              {SmartContract.burn_address_hash_string(), params.recipient, Decimal.new(params.amount)}

            first_topic == @zrc2_burnt_event ->
              {params.burn_account, SmartContract.burn_address_hash_string(), Decimal.new(params.amount)}
          end

        adapter_address_hash =
          case Map.fetch(log, :adapter_address_hash) do
            {:ok, adapter_address_hash} -> adapter_address_hash
            :error -> Map.get(adapter_address_hash_by_zrc2_address_hash, log.address_hash)
          end

        token_transfer = %{
          transaction_hash: log.transaction_hash,
          log_index: log.index,
          from_address_hash: from_address_hash,
          to_address_hash: to_address_hash,
          amount: amount,
          block_number: log.block_number,
          block_hash: log.block_hash
        }

        if is_nil(adapter_address_hash) do
          # the adapter address is unknown yet, so place the token transfer to the `zrc2_token_transfers` table
          {[Map.put(token_transfer, :zrc2_address_hash, log.address_hash) | zrc2_token_transfers_acc],
           token_transfers_acc}
        else
          # the adapter address is already known, so place the token transfer directly to the `token_transfers` table
          {zrc2_token_transfers_acc,
           [
             token_transfer
             |> Map.put(:token_contract_address_hash, adapter_address_hash)
             |> Map.put(:token_type, "ZRC-2")
             |> Map.put(:block_consensus, true)
             | token_transfers_acc
           ]}
        end
      end)

    tokens = Enum.map(token_transfers, &%{contract_address_hash: &1.token_contract_address_hash, type: &1.token_type})

    {:ok, _} =
      Chain.import(%{
        # todo: addresses: ...,
        tokens: %{params: tokens},
        token_transfers: %{params: token_transfers},
        zrc2_token_transfers: %{params: zrc2_token_transfers},
        timeout: :infinity
      })
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

  @spec zrc2_event_params(Data.t()) :: [map()]
  defp zrc2_event_params(log_data) do
    log_data
    |> decode_data([:string])
    |> Enum.at(0)
    |> Jason.decode!()
    |> Map.get("params")
    |> Enum.map(fn param -> {String.to_atom(param["vname"]), param["value"]} end)
    |> Enum.into(%{})
  end
end
