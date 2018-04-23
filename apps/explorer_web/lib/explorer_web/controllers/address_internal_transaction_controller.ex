defmodule ExplorerWeb.AddressInternalTransactionController do
  @moduledoc """
    Display all the Transactions that terminate at this Address.
  """

  use ExplorerWeb, :controller

  alias Explorer.Chain

  def index(conn, %{"address_id" => address_hash}) do
    case Chain.hash_to_address(address_hash) do
      {:ok, address} ->
        # options = [
        #   necessity_by_association: %{
        #     block: :required,
        #     from_address: :optional,
        #     to_address: :optional,
        #     receipt: :required
        #   },
        #   pagination: params
        # ]

        # page =
        #   Chain.address_to_transactions(
        #     address,
        #     Keyword.merge(options, current_filter(params))
        #   )

        render(conn, "index.html", address: address)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  # defp current_filter(params) do
  #   params
  #   |> Map.get("filter")
  #   |> case do
  #     "to" -> [direction: :to]
  #     "from" -> [direction: :from]
  #     _ -> []
  #   end
  # end
end
