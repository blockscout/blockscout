defmodule BlockScoutWeb.VisualizeSol2umlController do
  use BlockScoutWeb, :controller
  alias Explorer.Chain
  alias Explorer.Visualize.Sol2uml

  def index(conn, %{"type" => "JSON", "address" => address_hash_string}) do
    address_options = [
      necessity_by_association: %{
        :smart_contract => :optional
      }
    ]

    if Sol2uml.enabled?() do
      with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
           {:ok, address} <- Chain.find_contract_address(address_hash, address_options, true),
           # check that contract is verified. partial and twin verification is ok for this case
           false <- is_nil(address.smart_contract) do
        sources =
          address.smart_contract_additional_sources
          |> Enum.map(fn additional_source -> {additional_source.file_name, additional_source.contract_source_code} end)
          |> Enum.into(%{})
          |> Map.merge(%{
            get_contract_filename(address.smart_contract.file_path) => address.smart_contract.contract_source_code
          })

        params = %{
          sources: sources
        }

        case Sol2uml.visualize_contracts(params) do
          {:ok, svg} -> json(conn, %{"address" => address.hash, "contract_svg" => svg, "error" => nil})
          {:error, error} -> json(conn, %{"address" => address.hash, "contract_svg" => nil, "error" => error})
        end
      else
        _ -> json(conn, %{error: "contract not found or unverified"})
      end
    else
      not_found(conn)
    end
  end

  def index(conn, %{"address" => address_hash_string}) do
    with true <- Sol2uml.enabled?(),
         {:ok, _} <- Chain.string_to_address_hash(address_hash_string) do
      render(conn, "index.html",
        address: address_hash_string,
        get_svg_path: visualize_sol2uml_path(conn, :index, %{"type" => "JSON", "address" => address_hash_string})
      )
    else
      _ -> not_found(conn)
    end
  end

  def index(conn, _) do
    not_found(conn)
  end

  def get_contract_filename(nil), do: "main.sol"
  def get_contract_filename(filename), do: filename
end
