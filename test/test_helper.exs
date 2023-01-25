alias Commanded.Projections.Repo
alias Commanded.Projections.ConcurrentRepo

{:ok, _} = Repo.start_link()
{:ok, _} = ConcurrentRepo.start_link()

defmodule CreateProjections do
  use Ecto.Migration

  def change do
    create table(:projections) do
      add(:name, :text)
    end
  end
end

Ecto.Migrator.up(Repo, 99_999_999_999_999, CreateProjections)
Ecto.Migrator.up(ConcurrentRepo, 99_999_999_999_999, CreateProjections)

Mox.defmock(Commanded.EventStore.Adapters.Mock, for: Commanded.EventStore.Adapter)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)
