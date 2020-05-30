defmodule ProcaWeb.Resolvers.Campaign do
  import Ecto.Query


  def list(_, %{id: id}, _) do
    cl = list_query()
    |> where([x], x.id == ^id)
    |> Proca.Repo.all

    {:ok, cl}
  end

  def list(_, %{name: name}, _) do
    cl = list_query()
    |> where([x], x.name == ^name)
    |> Proca.Repo.all

    {:ok, cl}
  end

  def list(_, %{title: title}, _) do
    cl = list_query()
    |> where([x], like(x.title, ^title))
    |> Proca.Repo.all

    {:ok, cl}
  end

  def list(_, _, _) do
    cl = Proca.Repo.all list_query()
    {:ok, cl}
  end

  defp list_query() do
    from(x in Proca.Campaign, preload: [:org])
  end

  def stats(campaign, a, c) do
    IO.inspect(campaign, label: "Campaign")
    IO.inspect(a, label: "args")
    IO.inspect(c, label: "context")
    {supporters, at_cts} = Proca.Server.Stats.stats(campaign.id)
    {:ok,
     %{
       supporter_count: supporters,
       action_count: at_cts |> Enum.map(fn {at, ct} -> %{action_type: at, count: ct} end)
     }
    }
  end
end
