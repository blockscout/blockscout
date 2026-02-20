defmodule Explorer.Chain.CsvExport.Request do
  @moduledoc """
  Represents an asynchronous CSV export request.

  When the requested export period exceeds `CSV_EXPORT_ASYNC_LOAD_THRESHOLD`,
  the export is processed asynchronously via an Oban job. This schema tracks
  the request lifecycle and provides a UUID for the user to poll for the result.
  """

  use Explorer.Schema

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.CsvExport.{AsyncHelper, Worker}

  @primary_key false
  typed_schema "csv_export_requests" do
    field(:id, Ecto.UUID, primary_key: true, autogenerate: true)
    field(:remote_ip_hash, :binary, null: false)
    field(:file_id, :string)

    timestamps()
  end

  @required_attrs ~w(remote_ip_hash)a
  @optional_attrs ~w(file_id)a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = request, attrs \\ %{}) do
    request
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
  end

  @doc """
  Creates a new async CSV export request for the given remote IP address.

  The IP is hashed with SHA-256 before storage. Returns `{:ok, request}` on success,
  or `{:error, :too_many_pending_requests}` if the IP already has `max_pending_tasks`
  requests with `file_id` still `nil`.
  """
  @spec create(String.t(), map()) :: {:ok, t()} | {:error, any()}
  def create(remote_ip, args) do
    remote_ip_hash = hash_ip(remote_ip)
    max_pending = AsyncHelper.max_pending_tasks_per_ip()

    pending_count =
      __MODULE__
      |> where([r], r.remote_ip_hash == ^remote_ip_hash and is_nil(r.file_id))
      |> select([r], count(r.id))
      |> Repo.one()

    with {:pending_requests_count_overflow, false} <- {:pending_requests_count_overflow, pending_count >= max_pending},
         {:ok, request} <-
           %__MODULE__{remote_ip_hash: remote_ip_hash}
           |> changeset()
           |> Repo.insert(),
         {:ok, _job} <-
           args
           |> Map.put(:request_id, request.id)
           |> Worker.new()
           |> Oban.insert() do
      {:ok, request}
    else
      {:pending_requests_count_overflow, true} -> {:error, :too_many_pending_requests}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Updates the file_id for a given request_id.

  ## Parameters

  - `request_id`: The ID of the request to update.
  - `file_id`: The ID of the file to update.

  ## Returns
  - The number of rows updated and the result of the update.

  ## Examples

  ```elixir
  iex> update_file_id("123e4567-e89b-12d3-a456-426614174000", "123e4567-e89b-12d3-a456-426614174000")
  {1, nil}
  ```
  """
  @spec update_file_id(Ecto.UUID.t(), String.t()) :: {non_neg_integer(), nil}
  def update_file_id(request_id, file_id) do
    __MODULE__
    |> where([r], r.id == ^request_id)
    |> Repo.update_all(set: [file_id: file_id])
  end

  @doc """
  Gets a request by its UUID.

  ## Parameters

  - `uuid`: The UUID of the request to get.
  - `options`: The options to pass to the repository.

  ## Returns
  - The request or nil if no request is found.

  ## Examples

  ```elixir
  iex> get_by_uuid("123e4567-e89b-12d3-a456-426614174000")
  %Explorer.Chain.CsvExport.Request{id: "123e4567-e89b-12d3-a456-426614174000"}
  """
  @spec get_by_uuid(Ecto.UUID.t(), [Chain.api?()]) :: __MODULE__.t() | nil
  def get_by_uuid(uuid, options \\ []) do
    Chain.select_repo(options).get(__MODULE__, uuid)
  end

  @doc """
  Deletes a request by its ID.

  ## Parameters

  - `request_id`: The ID of the request to delete.

  ## Returns
  - The number of rows deleted and the result of the delete.

  ## Examples

  ```elixir
  iex> delete("123e4567-e89b-12d3-a456-426614174000")
  {1, nil}
  """
  @spec delete(Ecto.UUID.t()) :: {non_neg_integer(), nil}
  def delete(request_id) do
    __MODULE__
    |> where([r], r.id == ^request_id)
    |> Repo.delete_all()
  end

  defp hash_ip(ip) do
    :crypto.hash(:sha256, ip)
  end
end
