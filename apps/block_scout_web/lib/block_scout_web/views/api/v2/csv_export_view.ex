defmodule BlockScoutWeb.API.V2.CsvExportView do
  @moduledoc """
  View for CSV export API endpoints.
  """
  use BlockScoutWeb, :view

  def render("csv_export.json", %{request: %{status: status, file_id: file_id, expires_at: expires_at}}) do
    %{
      status: status,
      file_id: file_id,
      expires_at: expires_at
    }
  end
end
