defmodule Explorer.Chain.SmartContract.AuditReport do
  @moduledoc """
    The representation of an audit report for a smart contract.
  """

  use Explorer.Schema

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Hash
  alias Explorer.ThirdPartyIntegrations.AirTable

  @type t :: %__MODULE__{
          smart_contract_address_hash: Hash.Address.t(),
          is_approved: boolean(),
          submitter_name: String.t(),
          submitter_email: String.t(),
          is_project_owner: boolean(),
          project_name: String.t(),
          project_url: String.t(),
          audit_company_name: String.t(),
          audit_report_url: String.t(),
          audit_publish_date: Date.t(),
          request_id: String.t(),
          comment: String.t()
        }

  schema "smart_contract_audit_reports" do
    field(:smart_contract_address_hash, Hash.Address)
    field(:is_approved, :boolean)
    field(:submitter_name, :string)
    field(:submitter_email, :string)
    field(:is_project_owner, :boolean)
    field(:project_name, :string)
    field(:project_url, :string)
    field(:audit_company_name, :string)
    field(:audit_report_url, :string)
    field(:audit_publish_date, :date)
    field(:request_id, :string)
    field(:comment, :string)
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
      Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host] <>
        Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:path]

    request |> Map.from_struct() |> Map.drop(waste_fields) |> Map.put(:chain, chain)
  end

  @required_fields ~w(smart_contract_address_hash submitter_name submitter_email is_project_owner project_name project_url audit_company_name audit_report_url audit_publish_date)a
  @optional_fields ~w(comment is_approved request_id)a

  @doc """
    Returns a changeset for audit_report.
  """
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = audit_report, attrs \\ %{}) do
    audit_report
    |> cast(attrs, @optional_fields ++ @required_fields)
    |> validate_required(@required_fields, message: "Required")
    |> validate_format(:submitter_email, ~r/^[A-Z0-9._%+-]+@[A-Z0-9-]+.+.[A-Z]{2,4}$/i, message: "invalid email address")
  end

  @doc """
    Insert a new audit report to DB.
  """
  @spec create(map()) :: {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
    |> AirTable.submit()
  end

  @doc """
    Returns a list of audit reports by smart contract address hash.
  """
  @spec get_audit_reports_by_smart_contract_address_hash(Hash.Address.t(), keyword()) :: [__MODULE__.t()]
  def get_audit_reports_by_smart_contract_address_hash(address_hash, options \\ []) do
    __MODULE__
    |> where([ar], ar.smart_contract_address_hash == ^address_hash)
    |> where([ar], ar.is_approved == true)
    |> Chain.select_repo(options).all()
  end
end
