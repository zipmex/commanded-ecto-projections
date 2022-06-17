defmodule Commanded.Projections.ConcurrentRepo do
  use Ecto.Repo,
    otp_app: :commanded_ecto_projections,
    adapter: Ecto.Adapters.Postgres
end
