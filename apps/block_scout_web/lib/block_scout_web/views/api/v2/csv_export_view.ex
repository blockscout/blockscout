defmodule BlockScoutWeb.API.V2.CsvExportView do
  use BlockScoutWeb, :view

  def render("csv_export.json", %{request: %{status: status, file_id: file_id}}) do
    %{
      status: status,
      file_id: file_id
    }
  end
end
