defmodule EsotericDisplayMgr.Stream.Manager do
  alias EsotericDisplayMgr.Stream.UDPServer

  @doc """
  Spawns a new UDP server dynamically and returns the allocated port.
  """
  def open_stream(user, displays) do
    spec = {UDPServer, [user_id: user.id, owner_email: user.email, displays: displays]}

    case DynamicSupervisor.start_child(EsotericDisplayMgr.StreamSupervisor, spec) do
      {:ok, pid} ->
        port = GenServer.call(pid, :get_port)
        {:ok, port}

      error ->
        error
    end
  end

  @doc """
  Lists all active streams, filtered by the user's permissions.
  """
  def list_streams(scope) do
    alias EsotericDisplayMgr.Accounts
    can_manage? = Accounts.has_permission?(scope, "streams:manage")

    all_streams =
      Registry.select(EsotericDisplayMgr.StreamRegistry, [
        {{:"$1", :_, :"$2"}, [], [%{port: :"$1", meta: :"$2"}]}
      ])
      |> Enum.map(fn %{port: port, meta: meta} ->
        %{
          port: port,
          owner_id: meta[:user_id],
          owner_email: meta[:owner_email],
          display_labels: meta[:display_labels] || []
        }
      end)

    if can_manage? do
      all_streams
    else
      Enum.filter(all_streams, &(&1.owner_id == scope.user.id))
    end
  end

  @doc """
  Looks up the port in the Registry, verifies ownership, and shuts it down.
  """
  def close_stream(%EsotericDisplayMgr.Accounts.Scope{} = scope, port) do
    alias EsotericDisplayMgr.Accounts
    can_manage? = Accounts.has_permission?(scope, "stream:manage")

    case Registry.lookup(EsotericDisplayMgr.StreamRegistry, port) do
      [{pid, %{user_id: owner_id}}] ->
        if owner_id == scope.user.id or can_manage? do
          DynamicSupervisor.terminate_child(EsotericDisplayMgr.StreamSupervisor, pid)
          :ok
        else
          {:error, :unauthorized}
        end

      [] ->
        {:error, :not_found}
    end
  end

  def close_stream(%EsotericDisplayMgr.Accounts.User{} = user, post) do
    scope = %EsotericDisplayMgr.Accounts.Scope{user: user}
    close_stream(scope, post)
  end
end
