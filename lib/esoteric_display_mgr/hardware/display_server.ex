defmodule EsotericDisplayMgr.Hardware.DisplayServer do
  use GenServer
  require Logger

  alias EsotericDisplayMgr.Media

  def start_link(display_id) do
    GenServer.start_link(__MODULE__, display_id, name: via_tuple(display_id))
  end

  def via_tuple(display_id),
    do: {:via, Registry, {EsotericDisplayMgr.DisplayRegistry, display_id}}

  @impl true
  def init(display_id) do
    Phoenix.PubSub.subscribe(EsotericDisplayMgr.PubSub, "media:updates")
    Phoenix.PubSub.subscribe(EsotericDisplayMgr.PubSub, "display_queue:#{display_id}")

    {:ok, socket} = :gen_udp.open(0, [:binary])

    state = %{
      display_id: display_id,
      display: nil,
      target_ip: nil,
      target_port: nil,
      socket: socket,
      items: [],
      current_priority: nil,
      queue: [],
      playing_item: nil,
      playing_ref: nil,
      playing_frames: [],
      frame_index: 0,
      loops_done: 0,
      marquee_mode: false,
      rendered_cache: %{}
    }

    send(self(), :reevaluate)
    {:ok, state}
  end

  @impl true
  def handle_info(:reevaluate, state) do
    display = EsotericDisplayMgr.Repo.get!(EsotericDisplayMgr.Hardware.Display, state.display_id)
    {:ok, parsed_ip} = display.ip_address |> to_charlist() |> :inet.parse_address()

    new_state = %{state | display: display, target_ip: parsed_ip, target_port: display.port}

    media_items =
      Media.list_items()
      |> Enum.filter(fn i ->
        Enum.any?(i.displays, &(&1.id == new_state.display_id)) and
          i.priority <= display.required_priority
      end)
      |> Enum.map(&{:media, &1})

    streams =
      Registry.select(EsotericDisplayMgr.StreamRegistry, [
        {{:"$1", :_, :"$2"}, [], [%{port: :"$1", meta: :"$2"}]}
      ])
      |> Enum.filter(fn %{meta: meta} ->
        display.label in (meta[:display_labels] || []) and
          (meta[:priority] || 7) <= display.required_priority
      end)
      |> Enum.map(&{:stream, &1})

    all_eligible = media_items ++ streams

    if Enum.empty?(all_eligible) do
      stop_playing(new_state)
      {:noreply, %{new_state | queue: [], current_priority: nil, playing_item: nil}}
    else
      best_priority =
        all_eligible
        |> Enum.map(fn
          {:media, i} -> i.priority
          {:stream, s} -> s.meta[:priority] || 7
        end)
        |> Enum.min()

      best_items =
        Enum.filter(all_eligible, fn
          {:media, i} -> i.priority == best_priority
          {:stream, s} -> (s.meta[:priority] || 7) == best_priority
        end)
        |> Enum.shuffle()

      cond do
        new_state.current_priority != best_priority ->
          stop_playing(new_state)
          new_state2 = %{new_state | current_priority: best_priority, queue: best_items}
          {:noreply, play_next(new_state2)}

        true ->
          new_queue = update_queue(new_state.queue, best_items, new_state.playing_item)
          new_state2 = %{new_state | queue: new_queue}

          {:noreply,
           if(new_state2.playing_item == nil, do: play_next(new_state2), else: new_state2)}
      end
    end
  end

  def handle_info({:udp_packet, port, packet}, state) do
    case state.playing_item do
      {:stream, %{port: playing_port}} when playing_port == port ->
        :gen_udp.send(state.socket, state.target_ip, state.target_port, packet)

        Phoenix.PubSub.broadcast(
          EsotericDisplayMgr.PubSub,
          "display_preview:#{state.display_id}",
          {:preview_packet, packet}
        )

      _ ->
        :ok
    end

    {:noreply, state}
  end

  def handle_info(:next_item, state) do
    {:noreply, play_next(state)}
  end

  def handle_info(:play_frame, state) do
    if state.playing_item != nil and Enum.any?(state.playing_frames) do
      frame = Enum.at(state.playing_frames, state.frame_index)
      {:ok, bin} = Base.decode64(frame)
      :gen_udp.send(state.socket, state.target_ip, state.target_port, bin)

      Phoenix.PubSub.broadcast(
        EsotericDisplayMgr.PubSub,
        "display_preview:#{state.display_id}",
        {:preview_packet, bin}
      )

      next_idx = state.frame_index + 1

      {next_idx, loops} =
        if next_idx >= length(state.playing_frames),
          do: {0, state.loops_done + 1},
          else: {next_idx, state.loops_done}

      if state.marquee_mode and loops >= 2 do
        {:noreply, play_next(state)}
      else
        ref = Process.send_after(self(), :play_frame, 33)
        {:noreply, %{state | frame_index: next_idx, loops_done: loops, playing_ref: ref}}
      end
    else
      {:noreply, state}
    end
  end

  defp stop_playing(state) do
    if state.playing_ref, do: Process.cancel_timer(state.playing_ref)
  end

  defp play_next(state) do
    stop_playing(state)

    case state.queue do
      [] ->
        send(self(), :reevaluate)
        %{state | playing_item: nil}

      [item | rest] ->
        state = %{
          state
          | playing_item: item,
            queue: rest,
            frame_index: 0,
            loops_done: 0,
            playing_ref: nil,
            playing_frames: [],
            marquee_mode: false
        }

        case item do
          {:stream, _} ->
            ref = Process.send_after(self(), :next_item, 10_000)
            %{state | playing_ref: ref}

          {:media, media} ->
            frames =
              Map.get_lazy(state.rendered_cache, media.id, fn ->
                EsotericDisplayMgr.Media.Renderer.generate_ddp_stream(media, state.display)
              end)

            cache = Map.put(state.rendered_cache, media.id, frames)
            is_marquee = media.marquee != :none and length(frames) > 1

            ref =
              if(is_marquee) do
                send(self(), :play_frame)
                nil
              else
                send(self(), :play_frame)
                Process.send_after(self(), :next_item, 10_000)
              end

            %{
              state
              | playing_frames: frames,
                marquee_mode: is_marquee,
                playing_ref: ref,
                rendered_cache: cache
            }
        end
    end
  end

  defp update_queue(_current_queue, best_items, playing_item) do
    best_items
    |> Enum.reject(fn item ->
      id =
        case item do
          {:media, i} -> {:media, i.id}
          {:stream, s} -> {:stream, s.port}
        end

      playing_item != nil and
        id ==
          case playing_item do
            {:media, i} -> {:media, i.id}
            {:stream, s} -> {:stream, s.port}
          end
    end)
  end
end
