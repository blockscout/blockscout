defmodule BlockScoutWeb.VisualizeSol2umlController do
  use BlockScoutWeb, :controller
  alias Explorer.Chain
  alias Explorer.Visualize.Sol2uml

  def index(conn, %{"address" => address_hash_string}) do
    address_options = [
      necessity_by_association: %{
        :contracts_creation_internal_transaction => :optional,
        :names => :optional,
        :smart_contract => :optional,
        :token => :optional,
        :contracts_creation_transaction => :optional
      }
    ]
    with true <- Sol2uml.enabled?(),
         true <- Chain.smart_contract_fully_verified?(address_hash_string),
         {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.find_contract_address(address_hash, address_options, true) do
          sources = address.smart_contract_additional_sources
            |> Enum.map(fn (additional_source) -> {additional_source.file_name, additional_source.contract_source_code} end)
            |> Enum.into(%{})
            |> Map.merge(%{
              address.smart_contract.file_path => address.smart_contract.contract_source_code
            })
          params = %{
            sources: sources
          }
          case Sol2uml.visualize_contracts(params) do
            {:ok, svg} -> render(conn, "index.html", address: address, svg: svg, error: nil)
            {:error, error} -> render(conn, "index.html", address: address, svg: nil, error: error)
          end
    else
      _ -> not_found(conn)
    end
  end

  def index(conn, params) do
    not_found(conn)
  end
end
