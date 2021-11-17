alias Commanded.Projections.Repo

{:ok, _} = Repo.start_link()

defmodule CreateProjections do
  use Ecto.Migration

  def change do
    create table(:projections) do
      add(:name, :text)
      add(:value, :text)
    end
  end
end

Ecto.Migrator.up(Repo, 20_170_609_120_000, CreateProjections)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)
