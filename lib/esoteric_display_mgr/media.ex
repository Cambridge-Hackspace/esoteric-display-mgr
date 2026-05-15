defmodule EsotericDisplayMgr.Media do
  @moduledoc """
  The Media context.
  """
  import Ecto.Query, warn: false
  alias EsotericDisplayMgr.Repo
  alias EsotericDisplayMgr.Media.Item
  alias EsotericDisplayMgr.Accounts

  def list_items do
    Item
    |> Repo.all()
    |> Repo.preload(:displays)
  end

  def get_item!(id) do
    Item
    |> Repo.get!(id)
    |> Repo.preload(:displays)
  end

  def create_item(scope, attrs) do
    if Accounts.has_permission?(scope, "media:manage") do
      can_protect? = Accounts.has_permission?(scope, "media:protect")
      user_priority_cap = Accounts.get_priority_cap(scope)
      display_ids =
        attrs
        |> Map.get("display_ids", [])
        |> Enum.reject(&(&1 == ""))

      displays =
        EsotericDisplayMgr.Hardware.Display
        |> Repo.all()
        |> Enum.filter(
          &(&1.id in Enum.map(display_ids, fn id ->
              if is_binary(id), do: String.to_integer(id), else: id
            end))
        )

      %Item{}
      |> Item.changeset(attrs, user_priority_cap, can_protect?)
      |> Ecto.Changeset.put_assoc(:displays, displays)
      |> Repo.insert()
      |> broadcast_eval()
    else
      {:error, :unauthorized}
    end
  end

  def update_item(scope, %Item{} = item, attrs) do
    if Accounts.has_permission?(scope, "media:manage") do
      can_protect? = Accounts.has_permission?(scope, "media:protect")
      user_priority_cap = Accounts.get_priority_cap(scope)
      display_ids =
        attrs
        |> Map.get("display_ids", Enum.map(item.displays, & &1.id))
        |> Enum.reject(&(&1 == ""))

      displays =
        EsotericDisplayMgr.Hardware.Display
        |> Repo.all()
        |> Enum.filter(
          &(&1.id in Enum.map(display_ids, fn id ->
              if is_binary(id), do: String.to_integer(id), else: id
            end))
        )

      item
      |> Item.changeset(attrs, user_priority_cap, can_protect?)
      |> Ecto.Changeset.put_assoc(:displays, displays)
      |> Repo.update()
      |> broadcast_eval()
    else
      {:error, :unauthorized}
    end
  end

  def delete_item(scope, %Item{} = item) do
    if Accounts.has_permission?(scope, "media:manage") do
      if item.protected do
        {:error, :protected}
      else
        res = Repo.delete(item)
        broadcast_eval(res)
      end
    else
      {:error, :unauthorized}
    end
  end

  defp broadcast_eval({:ok, _item} = res) do
    Phoenix.PubSub.broadcast(EsotericDisplayMgr.PubSub, "media:updates", :reevaluate)
    res
  end

  defp broadcast_eval(err), do: err
end
