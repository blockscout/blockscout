defmodule Explorer.Chain.SmartContract.AuditReport do
  @moduledoc """
    The representation of an audit report for a smart contract.
  """

  use Explorer.Schema

  alias Explorer.{Chain, Helper, Repo}
  alias Explorer.Chain.Hash
  alias Explorer.ThirdPartyIntegrations.AirTable

  @max_reports_per_day_for_contract 5

  typed_schema "smart_contract_audit_reports" do
    field(:address_hash, Hash.Address, null: false)
    field(:is_approved, :boolean)
    field(:submitter_name, :string, null: false)
    field(:submitter_email, :string, null: false)
    field(:is_project_owner, :boolean, null: false)
    field(:project_name, :string, null: false)
    field(:project_url, :string, null: false)
    field(:audit_company_name, :string, null: false)
    field(:audit_report_url, :string, null: false)
    field(:audit_publish_date, :date, null: false)
    field(:request_id, :string)
    field(:comment, :string)

    timestamps()
  end

  @local_fields [:__meta__, :inserted_at, :updated_at, :id, :request_id]

  @doc """
    Returns a map representation of the request. Appends :chain to a resulting map
  """
  @spec to_map(__MODULE__.t()) :: map()
  def to_map(%__MODULE__{} = request) do
    association_fields = request.__struct__.__schema__(:associations)
    waste_fields = association_fields ++ @local_fields

    chain =
      Helper.get_app_host() <>
        Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:path]

    request |> Map.from_struct() |> Map.drop(waste_fields) |> Map.put(:chain, chain)
  end

  @required_fields ~w(address_hash submitter_name submitter_email is_project_owner project_name project_url audit_company_name audit_report_url audit_publish_date)a
  @optional_fields ~w(comment is_approved request_id)a

  @max_string_length 255
  @doc """
    Returns a changeset for audit_report.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = audit_report, attrs \\ %{}) do
    audit_report
    |> cast(attrs, @optional_fields ++ @required_fields)
    |> validate_required(@required_fields, message: "Required")
    |> validate_length(:submitter_email, max: @max_string_length)
    |> validate_format(:submitter_email, ~r/^[A-Z0-9._%+-]+@[A-Z0-9-]+.+.[A-Z]{2,4}$/i,
      message: "invalid email address"
    )
    |> validate_format(:submitter_name, ~r/[a-zA-Z ]+/i, message: "only letters are allowed")
    |> validate_length(:submitter_name, max: @max_string_length)
    |> validate_length(:project_name, max: @max_string_length)
    |> validate_length(:project_url, max: @max_string_length)
    |> validate_length(:audit_company_name, max: @max_string_length)
    |> validate_length(:audit_report_url, max: @max_string_length)
    |> validate_change(:audit_publish_date, &past_date?/2)
    |> validate_change(:audit_report_url, &valid_url?/2)
    |> validate_change(:project_url, &valid_url?/2)
    |> unique_constraint([:address_hash, :audit_report_url, :audit_publish_date, :audit_company_name],
      message: "the report was submitted before",
      name: :audit_report_unique_index
    )
    |> validate_change(:address_hash, &limit_not_exceeded?/2)
  end

  defp past_date?(field, date) do
    if Date.compare(Date.utc_today(), date) == :lt do
      [{field, "cannot be the future date"}]
    else
      []
    end
  end

  defp valid_url?(field, url) do
    if Helper.valid_url?(url) do
      []
    else
      [{field, "invalid url"}]
    end
  end

  defp limit_not_exceeded?(field, address_hash) do
    if get_reports_count_by_day_for_address_hash_by_day(address_hash) >= @max_reports_per_day_for_contract do
      [{field, "max #{@max_reports_per_day_for_contract} reports for address per day"}]
    else
      []
    end
  end

  @doc """
    Insert a new audit report to DB.
  """
  @spec create(map()) :: {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> AirTable.submit()
    |> Repo.insert()
  end

  defp get_reports_count_by_day_for_address_hash_by_day(address_hash) do
    __MODULE__
    |> where(
      [ar],
      ar.address_hash == ^address_hash and
        fragment("NOW() - ? at time zone 'UTC' <= interval '24 hours'", ar.inserted_at)
    )
    |> limit(@max_reports_per_day_for_contract)
    |> Repo.aggregate(:count)
  end

  @doc """
    Returns a list of audit reports by smart contract address hash.
  """
  @spec get_audit_reports_by_smart_contract_address_hash(Hash.Address.t(), keyword()) :: [__MODULE__.t()]
  def get_audit_reports_by_smart_contract_address_hash(address_hash, options \\ []) do
    __MODULE__
    |> where([ar], ar.address_hash == ^address_hash)
    |> where([ar], ar.is_approved == true)
    |> Chain.select_repo(options).all()
  end
end
