defmodule BlockScoutWeb.Plug.GraphQL do
  @behaviour Plug

  require Logger

  import Plug.Conn

  @query """
  {
    transaction(hash: "0x69e3923eef50eada197c3336d546936d0c994211492c9f947a24c02827568f9f") {
      blockNumber
      toAddressHash
      fromAddressHash
      createdContractAddressHash
      value
      status
      nonce
      hash
      error
      gas
      gasPrice
      gasUsed
      cumulativeGasUsed
      id
      index
      input
      r
      s
      v
    }
  }
  """

  def init(opts), do: opts

  def call(conn, _) do
    build_conn(conn)
  end

  defp build_conn(conn) do
    conn = %{conn | query_string: @query}

    conn
  end
end
