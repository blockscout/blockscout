defmodule BlockScoutWeb.AddressContractVerificationController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.{PublisherWorker, Solidity.CodeCompiler, Solidity.CompilerVersion}

  def new(conn, %{"address_id" => address_hash_string}) do
    changeset =
      SmartContract.changeset(
        %SmartContract{address_hash: address_hash_string},
        %{}
      )

    compiler_versions =
      case CompilerVersion.fetch_versions() do
        {:ok, compiler_versions} ->
          compiler_versions

        {:error, _} ->
          []
      end

    render(conn, "new.html",
      changeset: changeset,
      compiler_versions: compiler_versions,
      evm_versions: CodeCompiler.allowed_evm_versions(),
      address_hash: address_hash_string
    )
  end

  def create(
        conn,
        %{
          "smart_contract" => smart_contract,
          "external_libraries" => external_libraries
        }
      ) do
    Que.add(PublisherWorker, {smart_contract["address_hash"], smart_contract, external_libraries, conn})

    send_resp(conn, 204, "")
  end

  def parse_optimization_runs(%{"runs" => runs}) do
    case Integer.parse(runs) do
      {integer, ""} -> integer
      _ -> 200
    end
  end
end
