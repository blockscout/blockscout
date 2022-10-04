defmodule Explorer.Mailer do
  @moduledoc """
    Base module for mail sending

    add in your module:
    alias Explorer.Mailer

    and call
    Mailer.deliver_now!(email)
  """
  use Bamboo.Mailer, otp_app: :explorer
end
