defmodule EthereumJSONRPC.FetchedBeneficiaries do
  @moduledoc """
  Balance params and errors from a batch request to fetch beneficiaries.
  """

  alias EthereumJSONRPC.FetchedBeneficiary

  defstruct params_set: MapSet.new(),
            errors: []

  @typedoc """
   * `params_set` - all the balance request params from requests that succeeded in the batch.
   * `errors` - all the errors from requests that failed in the batch.
  """
  @type t :: %__MODULE__{params_set: MapSet.t(FetchedBeneficiary.params()), errors: [FetchedBeneficiary.error()]}
end
