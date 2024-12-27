defmodule Indexer.Fetcher.Zilliqa.ScillaSmartContracts do
  @moduledoc """
  Marks Scilla smart contracts as verified on the Zilliqa blockchain. These
  contracts are treated as verified since their code is stored on-chain,
  allowing for direct access.
  """
  alias Indexer.{BufferedTask, Tracer}
  require Logger

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  alias Explorer.Chain.{Address, Data, SmartContract}
  alias Explorer.Chain.Zilliqa.Reader

  @behaviour BufferedTask

  @default_max_batch_size 1
  @default_max_concurrency 1

  @doc false
  @spec child_spec([...]) :: Supervisor.child_spec()
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.put(:state, nil)

    Supervisor.child_spec(
      {BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]},
      id: __MODULE__
    )
  end

  def defaults do
    [
      poll: false,
      flush_interval: :timer.seconds(3),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: __MODULE__.TaskSupervisor,
      metadata: [fetcher: :scilla_smart_contracts]
    ]
  end

  @doc """
  Asynchronously fetches and processes a list of unique Scilla smart contract
  addresses for verification. If the associated supervisor is disabled,
  the function simply returns `:ok` without performing any action.

  ## Parameters

    - `entries`: A list of `Address.t()` structs representing contract addresses
      to be processed. Duplicates are removed before processing.
    - `realtime?`: A boolean indicating whether the fetching should occur with priority.
    - `timeout`: An integer representing the timeout duration (in milliseconds)
      for the fetch operation. Defaults to `5000`.

  ## Returns

    - `:ok`: Always returns `:ok`, either after queuing the unique entries for
      buffering or if the supervisor is disabled.
  """
  @spec async_fetch([Address.t()], boolean(), integer()) :: :ok
  def async_fetch(entries, realtime?, timeout \\ 5000) when is_list(entries) do
    if __MODULE__.Supervisor.disabled?() do
      :ok
    else
      BufferedTask.buffer(__MODULE__, entries |> Enum.uniq(), realtime?, timeout)
    end
  end

  @impl BufferedTask
  def init(initial, reducer, _json_rpc_named_arguments) do
    {:ok, final} =
      Reader.stream_unverified_scilla_smart_contract_addresses(
        initial,
        reducer,
        true
      )

    final
  end

  @doc """
  Processes a batch of unverified Scilla smart contract addresses, verifying
  each contract's validity and creating it in the database. The function
  verifies that each contract's code is a valid UTF-8 string. If valid, it
  attempts to create a new smart contract record.

  ## Parameters

    - `[Address.t()]`: A list of addresses, where each address is a struct with
      contract data to be verified.
    - `_opts`: Additional options for processing, currently unused.

  ## Returns

    - `:ok`: Indicates successful contract creation or if the contract code is
      invalid and therefore skipped.
    - `:retry`: Returned if an error occurs during contract creation, logging
      the failure for later retry.
  """

  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Fetcher.Zilliqa.ScillaSmartContracts.run/2",
              service: :indexer,
              tracer: Tracer
            )
  @spec run([Address.t()], any()) :: :ok | :retry
  def run([%Address{hash: address_hash, contract_code: %Data{} = contract_code}], _opts) do
    if String.valid?(contract_code.bytes) do
      %{
        address_hash: address_hash,
        contract_source_code: contract_code.bytes,
        optimization: false,
        language: :scilla
      }
      |> SmartContract.create_smart_contract()
      |> case do
        {:ok, _} ->
          :ok

        {:error, error} ->
          Logger.error("Failed to create smart contract for address: #{address_hash}\n#{inspect(error)}")
          :retry
      end
    else
      Logger.error("Invalid contract code. Skipping verification", %{address_hash: address_hash})
      :ok
    end
  end
end
