defmodule Commanded.Projections.TwoProjectorsTest do
  use ExUnit.Case

  import Commanded.Projections.ProjectionAssertions

  alias Ecto.Multi
  alias Commanded.Projections.Events.AnEvent
  alias Commanded.Projections.Projection
  alias Commanded.Projections.Repo

  defmodule SlowProjector do
    use Commanded.Projections.Ecto, application: TestApplication, name: "Projector"

    project %AnEvent{pid: pid, name: name}, _metadata, fn multi ->
      multi
      |> Multi.insert(:insert, fn _ ->
        send(pid, :middle_of_slow_projector)
        Process.sleep(1_000)
        %Projection{name: name}
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
      |> Multi.insert(:insert, fn _ ->
        IO.inspect("fast insert #{name}")
        %Projection{name: name}
      end)
    end
  end

  setup do
    start_supervised!(TestApplication)
    reset!()
    :ok
  end

  defp reset! do
    Repo.delete_all(Projection)
    Repo.delete_all(FastProjector.ProjectionVersion)
    Repo.delete_all(SlowProjector.ProjectionVersion)
    :ok
  end

  test "slow projector should return fail" do
    test_pid = self()

    FastProjector.handle(%AnEvent{name: "1_fast_projector"}, %{
      handler_name: "Projector",
      event_number: 1
    })

    slow_task =
      Task.async(fn ->
        SlowProjector.handle(%AnEvent{pid: test_pid, name: "2_slow_projector"}, %{
          handler_name: "Projector",
          event_number: 2
        })
      end)

    assert_receive :middle_of_slow_projector

    assert_raise Ecto.StaleEntryError, fn ->
      FastProjector.handle(%AnEvent{name: "2_fast_projector"}, %{
        handler_name: "Projector",
        event_number: 2
      })
    end

    assert :ok = Task.await(slow_task)

    assert_seen_event("Projector", 2)
    assert_projections(Projection, ["1_fast_projector", "2_slow_projector"])
  end
end
