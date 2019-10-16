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

    @max_retries 3

    def async_fetch(accounts) do
        if CeloAccountSupervisor.disabled?() do
          :ok
        else
          BufferedTask.buffer(__MODULE__, accounts, :infinity)
        end
    end

    @impl BufferedTask
    def init(initial, _, _) do
        #{:ok, final} = Chain.stream_unfetched_token_balances(initial, fn token_balance, acc ->
        #    token_balance
        #    |> entry()
        #    |> reducer.(acc)
        #end)

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

