defmodule Explorer.Account.Api.Plan do
  @moduledoc """
    Module is responsible for schema for API plans, each plan contains its name and maximum number of requests per second
  """
  use Explorer.Schema

  typed_schema "account_api_plans" do
    field(:name, :string)
    field(:max_req_per_second, :integer)

    timestamps()
  end
end
