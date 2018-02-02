defmodule Explorer.Repo do
  use Ecto.Repo, otp_app: :explorer
  use Scrivener, page_size: 10
  @dialyzer {:nowarn_function, rollback: 1}

  @doc """
  Dynamically loads the repository url from the
  DATABASE_URL environment variable.
  """
  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL"))}
  end
end
