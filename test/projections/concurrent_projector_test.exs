defmodule Commanded.Projections.ConcurrentProjectorTest do
  use ExUnit.Case

  alias Commanded.Projections.Events.AnEvent
  alias Commanded.Projections.Projection
  alias Commanded.Projections.ConcurrentRepo

  defmodule Projector do
    use Commanded.Projections.Ecto,
      application: TestApplication,
      repo: ConcurrentRepo,
      name: "Projector"

    project %AnEvent{name: name}, _metadata, fn multi ->
      Process.sleep(500)
      Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
    end
  end

  setup do
    reset!()
    start_supervised!(TestApplication)
    :ok
  end

  defp reset! do
    ConcurrentRepo.delete_all(Projection)
    ConcurrentRepo.delete_all(Projector.ProjectionVersion)
    :ok
  end

  test "one should be failed when trying to create a new projection version" do
    task1 =
      Task.async(fn ->
        try do
          Projector.handle(%AnEvent{name: "event_1"}, %{
            handler_name: "Projector",
            event_number: 1
          })
        catch
          kind, reason -> {:catch, kind, reason}
        end
      end)

    task2 =
      Task.async(fn ->
        try do
          Projector.handle(%AnEvent{name: "event_1"}, %{
            handler_name: "Projector",
            event_number: 1
          })
        catch
          kind, reason -> {:catch, kind, reason}
        end
      end)

    assert {[:ok],
            [
              {:catch, :error,
               %Ecto.ConstraintError{constraint: "projection_versions_pkey", type: :unique}}
            ]} =
             Task.await_many([task1, task2])
             |> Enum.split_with(&(&1 == :ok))

    assert %Projector.ProjectionVersion{last_seen_event_number: 1} =
             ConcurrentRepo.get(Projector.ProjectionVersion, "Projector")

    assert [%Projection{name: "event_1"}] = ConcurrentRepo.all(Projection)
  end

  test "one should be failed with stale error when trying to update projection version" do
    Projector.handle(%AnEvent{name: "event_1"}, %{
      handler_name: "Projector",
      event_number: 1
    })

    task1 =
      Task.async(fn ->
        try do
          Projector.handle(%AnEvent{name: "event_2"}, %{
            handler_name: "Projector",
            event_number: 2
          })
        catch
          kind, reason -> {:catch, kind, reason}
        end
      end)

    task2 =
      Task.async(fn ->
        try do
          Projector.handle(%AnEvent{name: "event_2"}, %{
            handler_name: "Projector",
            event_number: 2
          })
        catch
          kind, reason -> {:catch, kind, reason}
        end
      end)

    assert {[:ok], [{:catch, :error, %Ecto.StaleEntryError{}}]} =
             Task.await_many([task1, task2]) |> Enum.split_with(&(&1 == :ok))

    assert %Projector.ProjectionVersion{last_seen_event_number: 2} =
             ConcurrentRepo.get(Projector.ProjectionVersion, "Projector")

    assert [%Projection{name: "event_1"}, %Projection{name: "event_2"}] =
             ConcurrentRepo.all(Projection)
  end
end
