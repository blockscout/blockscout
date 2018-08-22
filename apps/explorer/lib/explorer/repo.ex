defmodule Explorer.Repo do
  use Ecto.Repo, otp_app: :explorer

  require Logger

  @doc """
  Dynamically loads the repository url from the
  DATABASE_URL environment variable.
  """
  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL"))}
  end

  @doc """
  Chunks elements into multiple `insert_all`'s to avoid DB driver param limits.

  *Note:* Should always be run within a transaction as multiple inserts may occur.
  """
  def safe_insert_all(kind, elements, opts) do
    returning = opts[:returning]

    elements
    |> Enum.chunk_every(1000)
    |> Enum.reduce({0, []}, fn chunk, {total_count, acc} ->
      {count, inserted} =
        try do
          insert_all(kind, chunk, opts)
        rescue
          exception ->
            old_truncate = Application.get_env(:logger, :truncate)
            Logger.configure(truncate: :infinity)

            Logger.error(fn ->
              [
                "Could not insert all of chunk into ",
                to_string(kind),
                " using options because of error.\n",
                "\n",
                "Chunk:\n",
                "\n",
                inspect(chunk, limit: :infinity, printable_limit: :infinity),
                "\n",
                "\n",
                "Options:\n",
                "\n",
                inspect(opts),
                "\n",
                "\n",
                "Exception:\n",
                "\n",
                Exception.format(:error, exception)
              ]
            end)

            Logger.configure(truncate: old_truncate)

            # reraise to kill caller
            raise exception
        end

      if returning do
        {count + total_count, acc ++ inserted}
      else
        {count + total_count, nil}
      end
    end)
  end
end
