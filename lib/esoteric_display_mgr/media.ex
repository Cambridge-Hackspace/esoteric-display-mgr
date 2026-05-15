defmodule EsotericDisplayMgr.Media do
  @moduledoc """
  The Media context.
  """
  import Ecto.Query, warn: false
  alias EsotericDisplayMgr.Repo
  alias EsotericDisplayMgr.Media.Item
  alias EsotericDisplayMgr.Accounts

  def list_items do
    Repo.all(Item)
  end

  def get_item!(id), do: Repo.get!(Item, id)

  def create_item(scope, attrs) do
    if Accounts.has_permission?(scope, "media:manage") do
      can_protect? = Accounts.has_permission?(scope, "media:protect")

      %Item{}
      |> Item.changeset(attrs, can_protect?)
      |> Repo.insert()
    else
      {:error, :unauthorized}
    end
  end

  def update_item(scope, %Item{} = item, attrs) do
    if Accounts.has_permission?(scope, "media:manage") do
      can_protect? = Accounts.has_permission?(scope, "media:protect")

      item
      |> Item.changeset(attrs, can_protect?)
      |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end

  def delete_item(scope, %Item{} = item) do
    if Accounts.has_permission?(scope, "media:manage") do
      if item.protected and not Accounts.has_permission?(scope, "media:protect") do
        {:error, :protected}
      else
        Repo.delete(item)
      end
    else
      {:error, :unauthorized}
    end
  end
end
