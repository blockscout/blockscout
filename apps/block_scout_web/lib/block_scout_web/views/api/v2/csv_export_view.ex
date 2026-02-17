defmodule BlockScoutWeb.API.V2.CsvExportView do
  use BlockScoutWeb, :view

  def render("csv_export.json", %{request: %{file_id: file_id}}) when not is_nil(file_id) do
    %{
      status: :success,
      file_id: file_id
    }
  end

  def render("csv_export.json", %{request: %{file_id: nil}}) do
    %{
      status: :pending,
      file_id: nil
    }
  end
end
