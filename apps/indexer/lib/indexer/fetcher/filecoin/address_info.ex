defmodule Indexer.Fetcher.Filecoin.AddressInfo do
  @moduledoc """
  A task for fetching Filecoin addresses info in the Address table using the
  Beryx API.

  Due to the lack of batch support in the API, addresses are fetched
  individually, making this fetching an expensive operation.
  """
  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  alias Ecto.Multi
  alias Explorer.Chain.Address
  alias Explorer.Repo
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Fetcher.Filecoin.AddressInfo.Supervisor, as: FilecoinAddressInfoSupervisor
  alias Indexer.Fetcher.Filecoin.{BeryxAPI, FilfoxAPI}

  alias Explorer.Chain.Filecoin.{
    NativeAddress,
    PendingAddressOperation
  }

  require Logger

  @http_error_codes 400..526

  @batch_size 1

  @behaviour BufferedTask

  @type filecoin_address_params :: %{
          filecoin_id: String.t(),
          filecoin_robust: String.t(),
          filecoin_actor_type: String.t() | nil
        }

  @actor_type_renaming %{
    "storagemarket" => "market",
    "storageminer" => "miner",
    "storagepower" => "power",
    "verifiedregistry" => "verifreg"
  }

  @doc """
  Asynchronously fetches filecoin addresses info
  """
  @spec async_fetch([PendingAddressOperation.t()], boolean(), integer()) :: :ok
  def async_fetch(pending_operations, realtime?, timeout \\ 5000)
      when is_list(pending_operations) do
    if FilecoinAddressInfoSupervisor.disabled?() do
      :ok
    else
      unique_operations =
        Enum.uniq_by(
          pending_operations,
          &to_string(&1.address_hash)
        )

      BufferedTask.buffer(__MODULE__, unique_operations, realtime?, timeout)
    end
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec` " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      defaults()
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec(
      {
        BufferedTask,
        [{__MODULE__, merged_init_opts}, gen_server_options]
      },
      id: __MODULE__
    )
  end

  @doc false
  @spec defaults() :: Keyword.t()
  def defaults do
    env = Application.get_env(:indexer, __MODULE__)

    [
      poll: false,
      flush_interval: :timer.seconds(30),
      max_concurrency: env[:concurrency],
      max_batch_size: @batch_size,
      task_supervisor: __MODULE__.TaskSupervisor,
      metadata: [fetcher: :filecoin_address_info]
    ]
  end

  @doc false
  @impl BufferedTask
  def init(initial, reducer, _json_rpc_named_arguments) do
    {:ok, final} =
      PendingAddressOperation.stream(
        initial,
        fn op, acc -> reducer.(op, acc) end
      )

    final
  end

  @doc """
  Fetches the Filecoin address info for the given pending operation.
  """
  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Fetcher.InternalTransaction.run/2",
              service: :indexer,
              tracer: Tracer
            )
  @spec run(
          [PendingAddressOperation.t()],
          EthereumJSONRPC.json_rpc_named_arguments()
        ) ::
          :ok | :retry
  def run([operation], json_rpc_named_arguments) do
    with true <- PendingAddressOperation.exists?(operation),
         {:ok, completeness, params} <- fetch(operation, json_rpc_named_arguments),
         {:ok, _} <-
           update_address_and_remove_or_update_operation(
             operation,
             completeness,
             params
           ) do
      :ok
    else
      false ->
        Logger.info("Pending address operation was already processed: #{to_string(operation.address_hash)}")
        :ok

      _ ->
        Logger.error("Could not fetch Filecoin address info: #{to_string(operation.address_hash)}")
        # TODO: We should consider implementing retry logic when fetching
        # becomes more stable
        :ok
    end
  end

  @spec fetch(
          PendingAddressOperation.t(),
          EthereumJSONRPC.json_rpc_named_arguments()
        ) ::
          {:ok, :full, filecoin_address_params()}
          | {:ok, :partial, filecoin_address_params()}
          | :error
  defp fetch(
         %PendingAddressOperation{address_hash: address_hash} = operation,
         json_rpc_named_arguments
       ) do
    eth_address_hash_string = to_string(address_hash)
    {:ok, native_address} = NativeAddress.cast(address_hash)

    strategies = [
      fn ->
        Logger.info("Fetching Filecoin address info for #{eth_address_hash_string} using Beryx API")
        full_fetch_address_info_using_beryx_api(operation)
      end,
      fn ->
        Logger.info("Fetching Filecoin address info for #{eth_address_hash_string} using Filfox API")
        full_fetch_address_info_using_filfox_api(operation)
      end,
      fn ->
        Logger.info("Fetching partial Filecoin address info for #{eth_address_hash_string} using JSON-RPC")
        partial_fetch_address_info_using_json_rpc(native_address, json_rpc_named_arguments)
      end,
      fn ->
        Logger.info("Deriving partial Filecoin address info for #{eth_address_hash_string}")
        partial_derive_address_info(native_address)
      end
    ]

    Enum.reduce_while(
      strategies,
      :error,
      fn strategy, _ ->
        case strategy.() do
          {:ok, _completeness, _params} = result -> {:halt, result}
          :error -> {:cont, :error}
        end
      end
    )
  end

  @spec full_fetch_address_info_using_beryx_api(PendingAddressOperation.t()) ::
          {:ok, :full, filecoin_address_params()} | :error
  defp full_fetch_address_info_using_beryx_api(operation) do
    with {:ok, body_json} <- operation.address_hash |> to_string() |> BeryxAPI.fetch_address_info(),
         {:ok, id_address_string} <- Map.fetch(body_json, "short"),
         {:ok, maybe_robust_address_string} <- Map.fetch(body_json, "robust"),
         {:ok, maybe_actor_type_string} <- Map.fetch(body_json, "actor_type") do
      robust_address_string =
        if maybe_robust_address_string in ["", "<empty>"] do
          operation.address_hash
          |> NativeAddress.cast()
          |> case do
            {:ok, native_address} -> to_string(native_address)
            _ -> nil
          end
        else
          maybe_robust_address_string
        end

      actor_type_string =
        maybe_actor_type_string
        |> case do
          "<unknown>" -> nil
          actor_type -> actor_type
        end
        |> rename_actor_type()

      {:ok, :full,
       %{
         filecoin_id: id_address_string,
         filecoin_robust: robust_address_string,
         filecoin_actor_type: actor_type_string
       }}
    else
      {:error, status_code, %{"error" => reason}} when status_code in @http_error_codes ->
        Logger.error("Beryx API returned error code #{status_code} with reason: #{reason}")
        :error

      error ->
        Logger.error("Error processing Beryx API response: #{inspect(error)}")
        :error
    end
  end

  @spec full_fetch_address_info_using_filfox_api(PendingAddressOperation.t()) ::
          {:ok, :full, filecoin_address_params()} | :error
  defp full_fetch_address_info_using_filfox_api(operation) do
    with {:ok, body_json} <- operation.address_hash |> to_string() |> FilfoxAPI.fetch_address_info(),
         Logger.info("Filfox API response: #{inspect(body_json)}"),
         {:ok, id_address_string} <- Map.fetch(body_json, "id"),
         {:ok, actor_type_string} <- Map.fetch(body_json, "actor") do
      renamed_actor_type = rename_actor_type(actor_type_string)

      {:ok, :full,
       %{
         filecoin_id: id_address_string,
         filecoin_robust: Map.get(body_json, "robust", id_address_string),
         filecoin_actor_type: renamed_actor_type
       }}
    else
      {:error, status_code, %{"error" => reason}} when status_code in @http_error_codes ->
        Logger.error("Filfox API returned error code #{status_code} with reason: #{reason}")
        :error

      error ->
        Logger.error("Error processing Filfox API response: #{inspect(error)}")
        :error
    end
  end

  defp rename_actor_type(actor_type) do
    Map.get(@actor_type_renaming, actor_type, actor_type)
  end

  @spec partial_fetch_address_info_using_json_rpc(
          NativeAddress.t(),
          EthereumJSONRPC.json_rpc_named_arguments()
        ) ::
          {:ok, :partial, filecoin_address_params()} | :error
  defp partial_fetch_address_info_using_json_rpc(native_address, json_rpc_named_arguments) do
    with %NativeAddress{protocol_indicator: 0} = id_address <- native_address,
         id_address_string = to_string(id_address),
         request =
           EthereumJSONRPC.request(%{
             id: 1,
             method: "Filecoin.StateAccountKey",
             params: [id_address_string, nil]
           }),
         {:ok, robust_address_string} when is_binary(robust_address_string) <-
           EthereumJSONRPC.json_rpc(request, json_rpc_named_arguments) do
      {:ok, :partial,
       %{
         filecoin_id: id_address_string,
         filecoin_robust: robust_address_string,
         filecoin_actor_type: nil
       }}
    else
      %NativeAddress{} ->
        Logger.error("Could not fetch address info using JSON RPC: not ID address")
        :error

      error ->
        Logger.error("Could not fetch address info using JSON RPC: #{inspect(error)}")
        :error
    end
  end

  @spec partial_derive_address_info(NativeAddress.t()) :: {:ok, :partial, filecoin_address_params()}
  defp partial_derive_address_info(native_address) do
    case native_address do
      %NativeAddress{protocol_indicator: 0} ->
        {:ok, :partial,
         %{
           filecoin_id: to_string(native_address),
           filecoin_robust: nil,
           filecoin_actor_type: nil
         }}

      %NativeAddress{protocol_indicator: 4, actor_id: 10} ->
        {:ok, :partial,
         %{
           filecoin_id: nil,
           filecoin_robust: to_string(native_address),
           filecoin_actor_type: nil
         }}

      _ ->
        :error
    end
  end

  @spec update_address_and_remove_or_update_operation(
          PendingAddressOperation.t(),
          :full | :partial,
          filecoin_address_params()
        ) ::
          {:ok, PendingAddressOperation.t()}
          | {:error, Ecto.Changeset.t()}
          | Ecto.Multi.failure()
  defp update_address_and_remove_or_update_operation(
         %PendingAddressOperation{} = operation,
         completeness,
         new_address_params
       ) do
    Multi.new()
    |> Multi.run(
      :acquire_address,
      fn repo, _ ->
        case repo.get_by(
               Address,
               [hash: operation.address_hash],
               lock: "FOR UPDATE"
             ) do
          nil -> {:error, :not_found}
          address -> {:ok, address}
        end
      end
    )
    |> Multi.run(
      :acquire_pending_address_operation,
      fn repo, _ ->
        case repo.get_by(
               PendingAddressOperation,
               [address_hash: operation.address_hash],
               lock: "FOR UPDATE"
             ) do
          nil -> {:error, :not_found}
          pending_operation -> {:ok, pending_operation}
        end
      end
    )
    |> Multi.run(
      :update_address,
      fn repo, %{acquire_address: address} ->
        address
        |> Address.changeset(new_address_params)
        |> repo.update()
      end
    )
    |> Multi.run(
      :delete_pending_operation,
      fn repo, %{acquire_pending_address_operation: operation} ->
        case completeness do
          :full ->
            repo.delete(operation)

          :partial ->
            # TODO: Implement proper calculation of `refetch_after` when retry
            # logic is implemented
            operation
            |> PendingAddressOperation.changeset(%{
              refetch_after: DateTime.utc_now()
            })
            |> repo.update()
        end
      end
    )
    |> Repo.transaction()
    |> tap(fn
      {:ok, _} -> :ok
      error -> Logger.error("Error updating address and removing pending operation: #{inspect(error)}")
    end)
  end
end
