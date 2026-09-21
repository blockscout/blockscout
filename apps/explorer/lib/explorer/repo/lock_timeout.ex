# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.LockTimeout do
  @moduledoc """
  Runs optional read queries which must fail fast instead of waiting for a
  table lock.

  PostgreSQL makes even a plain `SELECT` wait behind an `ACCESS EXCLUSIVE`
  lock, which is held for the whole duration of `VACUUM FULL`, `CLUSTER`,
  `TRUNCATE` and most `ALTER TABLE` forms. Without a lock timeout, an API
  request touching such a table hangs (and keeps a pool connection busy) until
  the lock is released or the query timeout fires, so a single maintenance
  operation on e.g. the `logs` table makes every address and transaction page
  unavailable.

  `run/3` executes the given function inside a transaction with the PostgreSQL
  `lock_timeout` parameter set for that transaction only (`SET LOCAL`). When a
  query inside waits for a lock longer than the timeout, the whole call returns
  `{:error, :lock_timeout}` and the caller can degrade its response instead of
  hanging. Queries which don't wait for any lock are not affected.

  The timeout is intended to be short: while a table is locked, every request
  waits for the timeout before falling back, so the wait multiplied by the
  request rate is the number of pool connections kept busy by the fallback.
  """

  require Logger

  @default_timeout 100

  @doc """
  Runs `fun` with the given repo inside a transaction with PostgreSQL
  `lock_timeout` set for that transaction.

  `fun` receives the repo and must use it for all its queries, so they run on
  the transaction connection.

  ## Options

  - `:lock_timeout` — the lock timeout in milliseconds; defaults to `timeout/0`.
  - other options are passed to the repo's `transaction/2` (e.g. `:timeout`).

  ## Returns

  - `{:ok, result}` where `result` is the return value of `fun`.
  - `{:error, :lock_timeout}` when a query inside `fun` waited for a lock
    longer than the lock timeout. The transaction is rolled back.
  - `{:error, reason}` when `fun` rolled the transaction back explicitly.
  """
  @spec run(module(), (module() -> result), Keyword.t()) :: {:ok, result} | {:error, :lock_timeout | term()}
        when result: term()
  def run(repo, fun, opts \\ []) when is_atom(repo) and is_function(fun, 1) and is_list(opts) do
    {lock_timeout, transaction_opts} = Keyword.pop(opts, :lock_timeout, timeout())

    if not (is_integer(lock_timeout) and lock_timeout > 0) do
      raise ArgumentError, "lock timeout must be a positive number of milliseconds, got: #{inspect(lock_timeout)}"
    end

    try do
      repo.transaction(
        fn ->
          # `SET` doesn't accept bind parameters; the value is a checked integer.
          repo.query!("SET LOCAL lock_timeout = #{lock_timeout}")
          fun.(repo)
        end,
        transaction_opts
      )
    rescue
      error in Postgrex.Error ->
        case error do
          %Postgrex.Error{postgres: %{code: :lock_not_available}} ->
            Logger.warning(fn ->
              [
                "Query on ",
                inspect(repo),
                " aborted after waiting for a table lock longer than ",
                to_string(lock_timeout),
                " ms"
              ]
            end)

            {:error, :lock_timeout}

          _ ->
            reraise error, __STACKTRACE__
        end
    end
  end

  @doc """
  The configured lock timeout in milliseconds.
  """
  @spec timeout() :: pos_integer()
  def timeout do
    Application.get_env(:explorer, __MODULE__, [])[:timeout] || @default_timeout
  end
end
