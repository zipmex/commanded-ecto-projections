use Mix.Config

# Print only warnings and errors during test
config :logger, :console, level: :warn, format: "[$level] $message\n"

config :commanded_ecto_projections,
  ecto_repos: [Commanded.Projections.Repo, Commanded.Projections.ConcurrentRepo],
  repo: Commanded.Projections.Repo

config :commanded_ecto_projections, Commanded.Projections.Repo,
  database: "commanded_ecto_projections_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :commanded_ecto_projections, Commanded.Projections.ConcurrentRepo,
  database: "commanded_ecto_projections_concurrent_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool_size: 5
