defmodule Indexer.Fetcher.Filecoin.NativeAddress do
  @moduledoc """
  A task for updating native Filecoin addresses in the Address table using the
  Beryx API.

  Due to the lack of batch support in the API, addresses are fetched
  individually, making this fetching an expensive operation.
  """
  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  alias Ecto.Multi
  alias Explorer.Repo
  alias Explorer.Chain.{Address, Filecoin.PendingAddressOperation, Hash}
  alias Indexer.Fetcher.Filecoin.BeryxAPI
  alias Indexer.Fetcher.Filecoin.NativeAddress.Supervisor, as: FilecoinNativeAddressSupervisor
  alias Indexer.{BufferedTask, Tracer}

  @batch_size 1

  @behaviour BufferedTask

  require Logger

  @doc """
  Asynchronously fetches native filecoin addresses
  """
  @spec async_fetch([PendingAddressOperation.t()], boolean(), integer()) :: :ok
  def async_fetch(pending_operations, realtime?, timeout \\ 5000)
      when is_list(pending_operations) do
    if FilecoinNativeAddressSupervisor.disabled?() do
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
      metadata: [fetcher: :filecoin_native_address]
    ]
  end

  @doc """
  Fetches the native Filecoin address for the given pending operation.
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
    with {:ok, new_params} <- fetch_address_info_using_beryx_api(address_hash),
         {:ok, _} <- update_address_and_remove_pending_operation(operation, new_params) do
      :ok
    else
      _ ->
        Logger.error("Could not fetch Filecoin native address: #{to_string(address_hash)}")
        :retry
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
  defp update_address_and_remove_pending_operation(operation, new_address_params) do
    Multi.new()
    |> Multi.run(
      :update_address,
      fn repo, _ ->
        %Address{hash: operation.address_hash}
        |> Address.changeset(new_address_params)
        |> repo.update()
      end
    )
    |> Multi.run(
      :delete_pending_operation,
      fn repo, _ ->
        repo.delete(operation)
      end
    )
    |> Repo.transaction()
  end

  @spec fetch_address_info_using_beryx_api(Hash.Address.t()) ::
          {:ok,
           %{
             filecoin_id: String.t(),
             filecoin_robust: String.t(),
             filecoin_actor_type: String.t()
           }}
          | :error
  defp fetch_address_info_using_beryx_api(address_hash) do
    with {:ok, body_json} <- address_hash |> to_string() |> BeryxAPI.fetch_account_info(),
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
      {:error, status_code, %{"error" => reason}} when status_code in 400..526 ->
        Logger.error("Beryx API returned error code #{status_code} with reason: #{reason}")
        :error

      error ->
        Logger.error("Error processing Beryx API response: #{inspect(error)}")
        :error
    end
  end
end
