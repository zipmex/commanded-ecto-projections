defmodule Commanded.Projections.TwoProjectorsTest do
  use ExUnit.Case

  import Commanded.Projections.ProjectionAssertions

  alias Ecto.Multi
  alias Commanded.Projections.Events.AnEvent
  alias Commanded.Projections.Projection
  alias Commanded.Projections.Repo

  defmodule SlowProjector do
    use Commanded.Projections.Ecto, application: TestApplication, name: "Projector"

    project %AnEvent{name: name}, _metadata, fn multi ->
      multi
      |> Multi.run(:projection, fn repo, _changes ->
        {:ok, repo.get_by(Projection, name: name) || %Projection{name: name}}
      end)
      |> Multi.run(:sleep, fn _, _ ->
        {:ok, Ecto.Adapters.SQL.query(Repo, "SELECT pg_sleep(10);")}
      end)
      |> Multi.insert_or_update(:upsert, fn %{projection: projection} ->
        Ecto.Changeset.change(projection, %Projection{value: "slow"})
      end)
    end

    # defp query(name) do
    #   Ecto.Adapters.SQL.query(
    #     Repo,
    #     """
    #     SELECT * from projections
    #       WHERE name = $1
    #       FOR UPDATE;
    #     """,
    #     [name]
    #   )
    # end
  end

  defmodule FastProjector do
    use Commanded.Projections.Ecto, application: TestApplication, name: "Projector"

    project %AnEvent{name: name}, _metadata, fn multi ->
      multi
      |> Multi.run(:projection, fn repo, _changes ->
        {:ok, repo.get_by(Projection, name: name) || %Projection{name: name}}
      end)
      |> Ecto.Multi.insert_or_update(:upsert, fn %{projection: projection} ->
        Ecto.Changeset.change(projection, %{value: UUID.uuid4()})
      end)
    end
  end

  setup do
    start_supervised!(TestApplication)
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "slow projector should return fail" do
    FastProjector.handle(%AnEvent{}, %{handler_name: "Projector", event_number: 1})

    Repo.all(Projection) |> IO.inspect(label: "all projections")

    slow_task =
      Task.async(fn ->
        SlowProjector.handle(%AnEvent{}, %{handler_name: "Projector", event_number: 1})
      end)

    fast_task =
      Task.async(fn ->
        FastProjector.handle(%AnEvent{}, %{handler_name: "Projector", event_number: 1})
      end)

    Task.await_many([slow_task, fast_task]) |> IO.inspect(label: "results of tasks")

    assert_projections(Projection, ["AnEvent"])
    Repo.all(Projection) |> IO.inspect(label: "all projections")
    assert_seen_event("Projector", 1)
  end
end
