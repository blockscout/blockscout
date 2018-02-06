defmodule Explorer.Repo do
  use Ecto.Repo, otp_app: :explorer
  use Scrivener, page_size: 100
  @dialyzer {:nowarn_function, rollback: 1}

  @doc """
  Dynamically loads the repository url from the
  DATABASE_URL environment variable.
  """
  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL"))}
  end

  defmodule NewRelic do
    use NewRelixir.Plug.Repo, repo: Explorer.Repo

    def paginate(queryable, opts \\ []) do
      Explorer.Repo.paginate(queryable, opts)
    end
  end
end
