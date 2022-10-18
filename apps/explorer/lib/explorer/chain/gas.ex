defmodule Explorer.Chain.Gas do
  @moduledoc """
  A measurement roughly equivalent to computational steps.  Every operation has a gas expenditure; for most operations
  it is ~3-10, although some expensive operations have expenditures up to 700 and a transaction itself has an
  expenditure of 21000.
  """

  @typedoc @moduledoc
  @type t :: false | nil | %Decimal{:coef => non_neg_integer(), :exp => integer(), :sign => -1 | 1}
end
