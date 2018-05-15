defmodule Explorer.Repo do
  use Ecto.Repo, otp_app: :explorer
  use Scrivener, page_size: 10

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
      {count, inserted} = insert_all(kind, chunk, opts)

      if returning do
        {count + total_count, acc ++ inserted}
      else
        {count + total_count, nil}
      end
    end)
  end
end
