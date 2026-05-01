defmodule BlockScoutWeb.Admin.TaskController do
  use BlockScoutWeb, :controller

  require Logger

  alias Explorer.Chain.ContractMethod

  @ok_resp Utils.JSON.encode!(%{status: "success"})
  @not_ok_resp Utils.JSON.encode!(%{status: "failure"})

  def create_contract_methods(conn, _) do
    case ContractMethod.import_all() do
      :ok ->
        send_resp(conn, 200, Utils.JSON.encode!(@ok_resp))

      {:error, error} ->
        Logger.error(fn -> ["Something went wrong while creating contract methods: ", inspect(error)] end)

        send_resp(conn, 500, Utils.JSON.encode!(@not_ok_resp))
    end
  end
end
