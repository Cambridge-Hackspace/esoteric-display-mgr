defmodule EsotericDisplayMgr.Hardware do
  @moduledoc """
  The Hardware context.
  """

  import Ecto.Query, warn: false
  alias EsotericDisplayMgr.Repo

  alias EsotericDisplayMgr.Hardware.Display
  alias EsotericDisplayMgr.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any display changes.

  The broadcasted messages match the pattern:

    * {:created, %Display{}}
    * {:updated, %Display{}}
    * {:deleted, %Display{}}

  """
  def subscribe_displays(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(EsotericDisplayMgr.PubSub, "user:#{key}:displays")
  end

  defp broadcast_display(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(EsotericDisplayMgr.PubSub, "user:#{key}:displays", message)
  end

  @doc """
  Returns the list of displays.

  ## Examples

      iex> list_displays(scope)
      [%Display{}, ...]

  """
  def list_displays(%Scope{} = scope) do
    Repo.all_by(Display, user_id: scope.user.id)
  end

  @doc """
  Gets a single display.

  Raises `Ecto.NoResultsError` if the Display does not exist.

  ## Examples

      iex> get_display!(scope, 123)
      %Display{}

      iex> get_display!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_display!(%Scope{} = scope, id) do
    Repo.get_by!(Display, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a display.

  ## Examples

      iex> create_display(scope, %{field: value})
      {:ok, %Display{}}

      iex> create_display(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_display(%Scope{} = scope, attrs) do
    with {:ok, display = %Display{}} <-
           %Display{}
           |> Display.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_display(scope, {:created, display})
      {:ok, display}
    end
  end

  @doc """
  Updates a display.

  ## Examples

      iex> update_display(scope, display, %{field: new_value})
      {:ok, %Display{}}

      iex> update_display(scope, display, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_display(%Scope{} = scope, %Display{} = display, attrs) do
    true = display.user_id == scope.user.id

    with {:ok, display = %Display{}} <-
           display
           |> Display.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_display(scope, {:updated, display})
      {:ok, display}
    end
  end

  @doc """
  Deletes a display.

  ## Examples

      iex> delete_display(scope, display)
      {:ok, %Display{}}

      iex> delete_display(scope, display)
      {:error, %Ecto.Changeset{}}

  """
  def delete_display(%Scope{} = scope, %Display{} = display) do
    true = display.user_id == scope.user.id

    with {:ok, display = %Display{}} <-
           Repo.delete(display) do
      broadcast_display(scope, {:deleted, display})
      {:ok, display}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking display changes.

  ## Examples

      iex> change_display(scope, display)
      %Ecto.Changeset{data: %Display{}}

  """
  def change_display(%Scope{} = scope, %Display{} = display, attrs \\ %{}) do
    true = display.user_id == scope.user.id

    Display.changeset(display, attrs, scope)
  end
end
