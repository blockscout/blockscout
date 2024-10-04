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
  alias Explorer.Chain.{Address, Filecoin.PendingAddressOperation}
  alias Explorer.Repo
  alias Indexer.Fetcher.Filecoin.AddressInfo.Supervisor, as: FilecoinAddressInfoSupervisor
  alias Indexer.Fetcher.Filecoin.BeryxAPI
  alias Indexer.{BufferedTask, Tracer}

  @http_error_codes 400..526

  @batch_size 1

  @behaviour BufferedTask

  require Logger

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

  @doc false
  @impl BufferedTask
  def init(initial, reducer, _) do
    {:ok, final} =
      PendingAddressOperation.stream(
        initial,
        fn op, acc -> reducer.(op, acc) end
      )

    final
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
  @spec run([Explorer.Chain.Filecoin.PendingAddressOperation.t(), ...], any()) :: :ok | :retry
  def run([pending_operation], _state) do
    fetch_and_update(pending_operation)
  end

  @spec fetch_and_update(PendingAddressOperation.t()) :: :ok | :retry
  defp fetch_and_update(%PendingAddressOperation{address_hash: address_hash} = operation) do
    with {:ok, new_params} <- fetch_address_info_using_beryx_api(operation),
         {:ok, _} <- update_address_and_remove_pending_operation(operation, new_params) do
      Logger.debug("Fetched Filecoin address info for: #{to_string(address_hash)}")
      :ok
    else
      _ ->
        Logger.error("Could not fetch Filecoin address info: #{to_string(address_hash)}")
        # TODO: We should consider implementing retry logic when fetching
        # becomes more stable
        :ok
    end
  end

  @spec update_address_and_remove_pending_operation(
          PendingAddressOperation.t(),
          %{
            filecoin_id: String.t(),
            filecoin_robust: String.t(),
            filecoin_actor_type: String.t()
          }
        ) ::
          {:ok, PendingAddressOperation.t()}
          | {:error, Ecto.Changeset.t()}
          | Ecto.Multi.failure()
  defp update_address_and_remove_pending_operation(
         %PendingAddressOperation{} = operation,
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
        repo.delete(operation)
      end
    )
    |> Repo.transaction()
    |> tap(fn
      {:ok, _} -> :ok
      error -> Logger.error("Error updating address and removing pending operation: #{inspect(error)}")
    end)
  end

  @spec fetch_address_info_using_beryx_api(PendingAddressOperation.t()) ::
          {:ok,
           %{
             filecoin_id: String.t(),
             filecoin_robust: String.t(),
             filecoin_actor_type: String.t()
           }}
          | :error
  defp fetch_address_info_using_beryx_api(%PendingAddressOperation{} = operation) do
    with {:ok, body_json} <- operation.address_hash |> to_string() |> BeryxAPI.fetch_account_info(),
         {:ok, id_address_string} <- Map.fetch(body_json, "short"),
         {:ok, robust_address_string} <- Map.fetch(body_json, "robust"),
         {:ok, actor_type_string} <- Map.fetch(body_json, "actor_type") do
      {:ok,
       %{
         filecoin_id: id_address_string,
         filecoin_robust: robust_address_string,
         filecoin_actor_type: actor_type_string
       }}
    else
      {:error, status_code, %{"error" => reason}} when status_code in @http_error_codes ->
        Logger.error("Beryx API returned error code #{status_code} with reason: #{reason}")

        operation
        |> PendingAddressOperation.changeset(%{http_status_code: status_code})
        |> Repo.update()
        |> case do
          {:ok, _} ->
            Logger.info("Updated pending operation with error status code")

          {:error, changeset} ->
            Logger.error("Could not update pending operation with error status code: #{inspect(changeset)}")
        end

        :error

      error ->
        Logger.error("Error processing Beryx API response: #{inspect(error)}")
        :error
    end
  end
end
