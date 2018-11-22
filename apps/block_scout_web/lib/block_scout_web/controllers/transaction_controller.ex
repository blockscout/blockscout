defmodule BlockScoutWeb.TransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1]

  alias Explorer.Chain

  def index(conn, params) do
    params_paging_options =
      params
      |> paging_options()
      # Decrease page size by 1, since the extra element is used in the infinite scroll.
      # After all pages are migrated to normal paging, the default page size
      # should be updated and this should be removed.
      |> Keyword.update!(:paging_options, &Map.update!(&1, :page_size, fn x -> x - 1 end))

    full_options =
      Keyword.merge(
        [
          necessity_by_association: %{
            :block => :required,
            [created_contract_address: :names] => :optional,
            [from_address: :names] => :optional,
            [to_address: :names] => :optional
          }
        ],
        params_paging_options
      )

    transactions = Chain.recent_collated_transactions(full_options)

    transaction_estimated_count = Chain.transaction_estimated_count()

    render(
      conn,
      "index.html",
      transaction_estimated_count: transaction_estimated_count,
      transactions: transactions,
      first_page_params: first_page_params(params),
      next_page_params: next_page_params(params),
      prev_page_params: prev_page_params(params)
    )
  end

  def show(conn, %{"id" => id}) do
    case Chain.string_to_transaction_hash(id) do
      {:ok, transaction_hash} -> show_transaction(conn, id, Chain.hash_to_transaction(transaction_hash))
      :error -> conn |> put_status(422) |> render("invalid.html", transaction_hash: id)
    end
  end

  defp next_page_params(%{"p" => page_number_string} = params) do
    page_number = String.to_integer(page_number_string)
    next_page_number = to_string(page_number + 1)
    Map.replace!(params, "p", next_page_number)
  end

  defp next_page_params(params) do
    Map.put_new(params, "p", "2")
  end

  defp first_page_params(%{"p" => "1"} = _params) do
    nil
  end

  defp first_page_params(%{"p" => _page_number} = params) do
    Map.delete(params, "p")
  end

  defp first_page_params(_params) do
    nil
  end

  defp prev_page_params(%{"p" => "1"} = _params) do
    nil
  end

  defp prev_page_params(%{"p" => page_number_string} = params) do
    page_number = String.to_integer(page_number_string)
    Map.replace!(params, "p", to_string(page_number - 1))
  end

  defp prev_page_params(_params) do
    nil
  end

  defp show_transaction(conn, id, {:error, :not_found}) do
    conn |> put_status(404) |> render("not_found.html", transaction_hash: id)
  end

  defp show_transaction(conn, id, {:ok, %Chain.Transaction{} = transaction}) do
    if Chain.transaction_has_token_transfers?(transaction.hash) do
      redirect(conn, to: transaction_token_transfer_path(conn, :index, id))
    else
      redirect(conn, to: transaction_internal_transaction_path(conn, :index, id))
    end
  end
end
