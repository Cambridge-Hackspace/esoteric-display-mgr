defmodule EsotericDisplayMgr.Stream.Manager do
  alias EsotericDisplayMgr.Stream.UDPServer

  @doc """
  Spawns a new UDP server dynamically and returns the allocated port.
  """
  def open_stream(user, displays) do
    spec = {UDPServer, [user_id: user.id, displays: displays]}

    case DynamicSupervisor.start_child(EsotericDisplayMgr.StreamSupervisor, spec) do
      {:ok, pid} ->
        port = GenServer.call(pid, :get_port)
        {:ok, port}

      error ->
        error
    end
  end

  @doc """
  Looks up the port in the Registry, verifies ownership, and shuts it down.
  """
  def close_stream(user, port) do
    case Registry.lookup(EsotericDisplayMgr.StreamRegistry, port) do
      [{pid, %{user_id: owner_id}}] ->
        if owner_id == user.id do
          DynamicSupervisor.terminate_child(EsotericDisplayMgr.StreamSupervisor, pid)
          :ok
        else
          {:error, :unauthorized}
        end

      [] ->
        {:error, :not_found}
    end
  end
end
