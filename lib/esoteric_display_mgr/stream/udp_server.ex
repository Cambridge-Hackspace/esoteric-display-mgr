defmodule EsotericDisplayMgr.Stream.UDPServer do
  use GenServer
  require Logger

  @doc """
  Starts the UDP server.
  Args must include:
  - `:user_id` (the ID of the user who opened this)
  - `:displays` (a list of %Display{} structs)
  """
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    user_id = Keyword.fetch!(args, :user_id)
    displays = Keyword.fetch!(args, :displays)

    targets =
      Enum.map(displays, fn display ->
        {:ok, ip_tuple} = display.ip_address |> to_charlist() |> :inet.parse_address()
        {ip_tuple, display.port}
      end)

    case :gen_udp.open(0, [:binary, active: true]) do
      {:ok, socket} ->
        {:ok, port} = :inet.port(socket)
        Registry.register(EsotericDisplayMgr.StreamRegistry, port, %{user_id: user_id})
        Logger.info("Opened UDP multiplexer on port #{port} for user #{user_id}")
        {:ok, %{socket: socket, port: port, targets: targets, user_id: user_id}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:get_port, _from, state) do
    {:reply, state.port, state}
  end

  @impl true
  def handle_info({:udp, _socket, _ip, _in_port, packet}, state) do
    Enum.each(state.targets, fn {target_ip, target_port} ->
      :gen_udp.send(state.socket, target_ip, target_port, packet)
    end)

    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Closing UDP multiplexer on port #{state.port}. Reason: #{inspect(reason)}")
    :gen_udp.close(state.socket)
  end
end
