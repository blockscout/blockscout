defmodule Explorer.ThirdPartyIntegrations.AirTableAuditReport do
  @moduledoc """
    Module is responsible for submitting audit reports to AirTable
  """
  require Logger

  alias Ecto.Changeset
  alias Explorer.Chain.SmartContract.AuditReport
  alias Explorer.HttpClient

  @doc """
    Submits a public tags request or audit report to AirTable
  """
  @spec submit(Changeset.t()) :: Changeset.t()
  @spec submit({:ok, AuditReport.t()} | {:error, Changeset.t()}, Changeset.t()) :: Changeset.t()

  def submit(%Changeset{} = changeset), do: submit(Changeset.apply_action(changeset, :insert), changeset)

  def submit({:ok, %AuditReport{} = audit_report}, changeset) do
    submit_entry(
      AuditReport.to_map(audit_report),
      :air_table_audit_reports,
      fn request_id ->
        changeset
        |> Changeset.put_change(:request_id, request_id)
      end,
      fn ->
        changeset
        |> Changeset.add_error(:smart_contract_address_hash, "AirTable error. Please try again later")
      end
    )
  end

  def submit(_error, changeset), do: changeset

  defp submit_entry(map, envs_key, success_callback, failure_callback) do
    envs = Application.get_env(:explorer, envs_key)
    api_key = envs[:api_key]
    headers = [{"Authorization", "Bearer #{api_key}"}, {"Content-Type", "application/json"}]
    url = envs[:table_url]

    body = %{
      "typecast" => true,
      "records" => [%{"fields" => map}]
    }

    request = HttpClient.post(url, Jason.encode!(body), headers)

    case request do
      {:ok, %{body: body, status_code: 200}} ->
        request_id = Enum.at(Jason.decode!(body)["records"], 0)["fields"]["request_id"]

        success_callback.(request_id)

      error ->
        Logger.error(fn -> ["Error while submitting AirTable entry", inspect(error)] end)

        failure_callback.()
    end
  end
end
