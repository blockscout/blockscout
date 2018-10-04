defmodule Explorer.Scheduler do
  @moduledoc "module to run periodical tasks"
  use Quantum.Scheduler,
    otp_app: :explorer
end
