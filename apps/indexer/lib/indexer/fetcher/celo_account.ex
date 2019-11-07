defmodule Indexer.Fetcher.CeloAccount do

    use Indexer.Fetcher
    use Spandex.Decorators

    require Logger

    alias Indexer.Fetcher.CeloAccount.Supervisor, as: CeloAccountSupervisor
    alias Explorer.Chain.CeloAccount
    alias Explorer.Chain
    alias Explorer.Celo.AccountReader

    alias Indexer.BufferedTask

    @behaviour BufferedTask

    @defaults [
        flush_interval: 300,
        max_batch_size: 100,
        max_concurrency: 10,
        task_supervisor: Indexer.Fetcher.CeloAccount.TaskSupervisor
    ]

    @max_retries 3

    def async_fetch(accounts) do
        if CeloAccountSupervisor.disabled?() do
          :ok
        else
          params =
            accounts.params
            |> Enum.map(&entry/1)

          BufferedTask.buffer(__MODULE__, params, :infinity)
        end
    end

    def entry(address) do
      %{
        address: address,
        retries_count: 0
      }
    end

    @doc false
    def child_spec([init_options, gen_server_options]) do
        merged_init_opts =
            @defaults
            |> Keyword.merge(init_options)
            |> Keyword.put(:state, {0, []})

        Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
    end

    @impl BufferedTask
    def init(initial, _, _) do
        initial
    end

    @impl BufferedTask
    def run(accounts, _json_rpc_named_arguments) do
      failed_list =
            accounts
            |> Enum.map(&Map.put(&1, :retries_count, &1.retries_count + 1))
            |> fetch_from_blockchain()
            |> import_accounts()

        if failed_list == [] do
            :ok
        else
            {:retry, failed_list}
        end
    end

    defp fetch_from_blockchain(addresses) do
        addresses
        |> Enum.filter(&(&1.retries_count <= @max_retries))
        |> Enum.map(fn %{address: address} = account ->
          case AccountReader.account_data(address) do
            {:ok, data} ->
              Map.merge(account, data)
    
            error ->
              Map.put(account, :error, error)
          end
        end)
    end

    defp import_accounts(accounts) do
        {failed, success} =
          Enum.reduce(accounts, {[], []}, fn
            %{error: _error} = account, {failed, success} ->
              {[account | failed], success}
    
            account, {failed, success} ->
              changeset = CeloAccount.changeset(%CeloAccount{}, account)
    
              if changeset.valid? do
                {failed, [changeset.changes | success]}
              else
                {[account | failed], success}
              end
          end)
    
        import_params = %{
          celo_accounts: %{params: success},
          timeout: :infinity
        }

        case Chain.import(import_params) do
          {:ok, _} ->
            :ok
    
          {:error, reason} ->
            Logger.debug(fn -> ["failed to import Celo account data: ", inspect(reason)] end,
              error_count: Enum.count(accounts)
            )
        end
    
        failed
    end


end

