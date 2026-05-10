defmodule EsotericDisplayMgr.Accounts.Permissions do
  @moduledoc """
  Defines the list of valid permissions for the system.
  """

  @available_permissions [
    "users:manage",
    "displays:manage",
    "displays:list",
    "media:manage",
    "media:protect",
    "stream:connect",
    "stream:manage",
    "priority:manage",
    "priority:override",
    "roles:manage"
  ]

  @doc """
  Returns a list of all available permissions.
  """
  def all, do: @available_permissions

  @doc """
  Checks if a given permission string is valid in the system.
  """
  def valid?(permission), do: permission in @available_permissions
end
