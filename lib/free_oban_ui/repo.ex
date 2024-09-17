defmodule FreeObanUi.Repo do
  use Ecto.Repo,
    otp_app: :free_oban_ui,
    adapter: Ecto.Adapters.Postgres
end
