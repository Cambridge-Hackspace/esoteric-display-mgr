defmodule EsotericDisplayMgr.Media.Renderer do
  @moduledoc """
  The modular engine that converts a Media Item into a stream of DDP packets
  tailored for a specific Display's parameters.
  """
  require Logger
  import Bitwise
  alias EsotericDisplayMgr.Stream.DDP
  alias EsotericDisplayMgr.Hardware.Display
  alias EsotericDisplayMgr.Media.Item

  @doc """
  Generates a list of Base64 encoded DDP packets representing the frames
  of the media item, formatted for the given display.
  """
  def generate_ddp_stream(%Item{} = item, %Display{} = display) do
    item
    |> loading(display)
    |> resizing(item, display)
    |> animating(item, display)
    |> deduplication()
    |> Enum.map(&colorizing(&1, display))
    |> rendering()
  end

  defp ensure_rgba(img) do
    {:ok, img} = Image.to_colorspace(img, :srgb)
    {:ok, img} = Image.cast(img, {:u, 8})

    if Image.has_alpha?(img) do
      img
    else
      {:ok, with_alpha} = Image.add_alpha(img, 255)
      with_alpha
    end
  end

  defp force_memory(img) do
    case Vix.Vips.Image.copy_memory(img) do
      {:ok, mem_img} -> mem_img
      _ -> img
    end
  end

  # --- 1. LOADING ---

  defp loading(%Item{media_type: :text, content: text}, display) do
    target_height = max(1, round(display.height * 0.90))

    case Image.Text.text(text,
           text_fill_color: :white,
           font_size: target_height
         ) do
      {:ok, text_img} ->
        img_w = max(Image.width(text_img), display.width)

        {:ok, canvas} = Image.new(img_w, display.height, color: [0, 0, 0, 255])
        {:ok, canvas} = Image.cast(canvas, {:u, 8})
        text_rgba = ensure_rgba(text_img)

        x_offset =
          if Image.width(text_img) < display.width,
            do: div(display.width - Image.width(text_img), 2),
            else: 0

        y_offset = div(display.height - Image.height(text_img), 2)
        {:ok, composed} = Image.compose(canvas, text_rgba, x: x_offset, y: y_offset)
        [force_memory(composed)]

      {:error, reason} ->
        Logger.error("Failed to render text: #{inspect(reason)}")
        fallback_image(display)
    end
  end

  defp loading(%Item{media_type: type, content: path}, display) when type in [:image, :gif] do
    priv_path = Path.join(:code.priv_dir(:esoteric_display_mgr), "static" <> path)

    if File.exists?(priv_path) do
      opts =
        if type == :gif do
          [access: :sequential, pages: :all, fail_on: :none]
        else
          [access: :sequential, fail_on: :none]
        end

      case Image.open(priv_path, opts) do
        {:ok, img} ->
          extract_frames(img)

        {:error, reason} ->
          Logger.error("Failed to open image at #{priv_path}: #{inspect(reason)}")
          fallback_image(display)
      end
    else
      Logger.error("Media file missing from disk: #{priv_path}")
      fallback_image(display)
    end
  end

  defp extract_frames(img) do
    case Vix.Vips.Image.header_value(img, "n-pages") do
      {:ok, pages} when is_integer(pages) and pages > 1 ->
        total_height = Image.height(img)

        page_height =
          case Vix.Vips.Image.header_value(img, "page-height") do
            {:ok, ph} when is_integer(ph) and ph > 0 -> ph
            _ -> max(1, div(total_height, pages))
          end

        width = Image.width(img)
        loaded_pages = div(total_height, page_height)

        frames =
          0..(max(1, loaded_pages) - 1)
          |> Enum.flat_map(fn i ->
            y_offset = i * page_height

            if y_offset + page_height <= total_height do
              case Vix.Vips.Operation.extract_area(img, 0, y_offset, width, page_height) do
                {:ok, cropped} -> [cropped |> ensure_rgba() |> force_memory()]
                _ -> []
              end
            else
              []
            end
          end)

        if frames == [], do: [ensure_rgba(img) |> force_memory()], else: frames

      _ ->
        [ensure_rgba(img) |> force_memory()]
    end
  end

  defp fallback_image(%Display{} = display) do
    w = max(1, display.width)
    h = max(1, display.height)
    {:ok, img} = Image.new(w, h, color: [255, 0, 0, 255])
    img |> ensure_rgba() |> force_memory() |> List.wrap()
  end

  # --- 2. RESIZING ---

  defp resizing(frames, item, display) do
    effective_marquee = if item.media_type == :gif, do: :none, else: item.marquee
    Enum.map(frames, &apply_sizing(&1, display, item.sizing, effective_marquee))
  end

  defp apply_sizing(img, display, :stretch, _marquee) do
    scale_x = display.width / Image.width(img)
    scale_y = display.height / Image.height(img)
    {:ok, resized} = Vix.Vips.Operation.resize(img, scale_x, vscale: scale_y)
    force_memory(resized)
  end

  defp apply_sizing(img, display, :zoom, _marquee) do
    scale_x = display.width / Image.width(img)
    scale_y = display.height / Image.height(img)
    scale = min(scale_x, scale_y)

    {:ok, resized} = Image.resize(img, scale)
    rw = Image.width(resized)
    rh = Image.height(resized)

    {:ok, canvas} = Image.new(display.width, display.height, color: [0, 0, 0, 255])
    {:ok, canvas} = Image.cast(canvas, {:u, 8})

    {:ok, composed} =
      Image.compose(canvas, ensure_rgba(resized),
        x: div(display.width - rw, 2),
        y: div(display.height - rh, 2)
      )

    force_memory(composed)
  end

  defp apply_sizing(img, display, :crop, marquee) do
    scale_x = display.width / Image.width(img)
    scale_y = display.height / Image.height(img)
    scale = max(scale_x, scale_y)

    {:ok, resized} = Image.resize(img, scale)
    rw = Image.width(resized)
    rh = Image.height(resized)

    marquee_enabled? = marquee != :none

    crop_w = if marquee_enabled? and marquee in [:ltr, :rtl], do: rw, else: display.width
    crop_w = min(crop_w, rw)

    crop_h = if marquee_enabled? and marquee in [:utd, :dtu], do: rh, else: display.height
    crop_h = min(crop_h, rh)

    crop_x = div(rw - crop_w, 2)
    crop_y = div(rh - crop_h, 2)

    {:ok, cropped} = Vix.Vips.Operation.extract_area(resized, crop_x, crop_y, crop_w, crop_h)
    force_memory(cropped)
  end

  # --- 3. ANIMATING ---

  defp animating(frames, %Item{media_type: :gif}, _display), do: frames
  defp animating(frames, %Item{marquee: :none}, _display), do: frames

  defp animating(frames, item, display) do
    img = List.first(frames)
    w = Image.width(img)
    h = Image.height(img)

    {_from_side, sigma_count} =
      case item.marquee do
        :ltr -> {:left, display.width}
        :rtl -> {:right, display.width}
        :utd -> {:top, display.height}
        :dtu -> {:bottom, display.height}
      end

    padded = pad_for_marquee(img, item.marquee, sigma_count, w, h)
    slice_marquee_frames(padded, item.marquee, sigma_count, w, h, display)
  end

  defp pad_for_marquee(img, marquee, sigma_count, w, h) do
    case marquee do
      d when d in [:ltr, :rtl] ->
        {:ok, canvas} = Image.new(w + 2 * sigma_count, h, color: [0, 0, 0, 255])
        {:ok, canvas} = Image.cast(canvas, {:u, 8})
        {:ok, composed} = Image.compose(canvas, ensure_rgba(img), x: sigma_count, y: 0)
        composed

      d when d in [:utd, :dtu] ->
        {:ok, canvas} = Image.new(w, h + 2 * sigma_count, color: [0, 0, 0, 255])
        {:ok, canvas} = Image.cast(canvas, {:u, 8})
        {:ok, composed} = Image.compose(canvas, ensure_rgba(img), x: 0, y: sigma_count)
        composed
    end
  end

  defp slice_marquee_frames(padded, marquee, sigma_count, w, h, display) do
    case marquee do
      :ltr ->
        total_steps = w + sigma_count

        Enum.map(total_steps..0//-1, fn x ->
          {:ok, cropped} =
            Vix.Vips.Operation.extract_area(padded, x, 0, display.width, display.height)

          force_memory(cropped)
        end)

      :rtl ->
        total_steps = w + sigma_count

        Enum.map(0..total_steps, fn x ->
          {:ok, cropped} =
            Vix.Vips.Operation.extract_area(padded, x, 0, display.width, display.height)

          force_memory(cropped)
        end)

      :utd ->
        total_steps = h + sigma_count

        Enum.map(total_steps..0//-1, fn y ->
          {:ok, cropped} =
            Vix.Vips.Operation.extract_area(padded, 0, y, display.width, display.height)

          force_memory(cropped)
        end)

      :dtu ->
        total_steps = h + sigma_count

        Enum.map(0..total_steps, fn y ->
          {:ok, cropped} =
            Vix.Vips.Operation.extract_area(padded, 0, y, display.width, display.height)

          force_memory(cropped)
        end)
    end
  end

  defp deduplication(frames) do
    len = length(frames)

    if rem(len, 2) != 0 do
      frames
    else
      half = div(len, 2)
      {first_half, second_half} = Enum.split(frames, half)

      if images_equal?(first_half, second_half) do
        deduplication(first_half)
      else
        frames
      end
    end
  end

  defp images_equal?(half1, half2) do
    Enum.zip(half1, half2)
    |> Enum.all?(fn {img1, img2} ->
      to_binary!(img1) == to_binary!(img2)
    end)
  end

  # --- 5. COLORIZING ---

  defp colorizing(img, display) do
    img =
      if Image.has_alpha?(img) do
        {:ok, flattened} = Image.flatten(img, background_color: [0, 0, 0])
        flattened
      else
        img
      end

    format =
      case display.bits_per_channel do
        b when b in [1, 4, 8] -> {:u, 8}
        16 -> {:u, 16}
        b when b in [24, 32] -> {:u, 32}
        _ -> {:u, 8}
      end

    {raw_pixels, ddp_type} =
      case display.color_type do
        "Grayscale" ->
          {:ok, img} = Image.to_colorspace(img, :bw)
          {:ok, img} = Image.cast(img, format)
          raw_binary = to_binary!(img)
          {raw_binary, :grayscale}

        "HSL" ->
          {:ok, img} = Image.to_colorspace(img, :hsl)
          {:ok, img} = Image.cast(img, format)
          raw_binary = to_binary!(img)
          {raw_binary, :hsl}

        "RGBW" ->
          {:ok, w_band} = Image.new(Image.width(img), Image.height(img), color: [0])
          {:ok, w_band} = Image.cast(w_band, format)

          {:ok, img} = Image.to_colorspace(img, :srgb)
          {:ok, img} = Image.cast(img, format)
          img = bandjoin!(img, w_band)
          raw_binary = to_binary!(img)

          {raw_binary, :rgbw32}

        _ ->
          {:ok, img} = Image.to_colorspace(img, :srgb)
          {:ok, img} = Image.cast(img, format)
          raw_binary = to_binary!(img)
          {raw_binary, :rgb24}
      end

    {raw_pixels, ddp_type, display.bits_per_channel}
  end

  # --- 6. RENDERING ---

  defp rendering(colorized_frames) do
    colorized_frames
    |> Enum.with_index()
    |> Enum.map(fn {{raw_pixels, ddp_type, bits}, idx} ->
      sequence = rem(idx, 16)

      raw_pixels
      |> adjust_bit_depth(bits)
      |> DDP.encode(sequence: sequence, type: ddp_type, dest_id: 0)
      |> Base.encode64()
    end)
  end

  defp adjust_bit_depth(binary, 1), do: for(<<c::8 <- binary>>, into: <<>>, do: <<bsr(c, 7)::8>>)
  defp adjust_bit_depth(binary, 4), do: for(<<c::8 <- binary>>, into: <<>>, do: <<bsr(c, 4)::8>>)

  defp adjust_bit_depth(binary, 24),
    do: for(<<c::native-32 <- binary>>, into: <<>>, do: <<bsr(c, 8)::24>>)

  defp adjust_bit_depth(binary, _bits), do: binary

  defp to_binary!(img) do
    case Vix.Vips.Image.write_to_binary(img) do
      {:ok, binary} ->
        binary

      {:error, reason} ->
        Logger.error("libvips pipeline evaluation failed: #{inspect(reason)}")
        <<0>>
    end
  end

  defp bandjoin!(img, band) do
    {:ok, joined} = Vix.Vips.Operation.bandjoin([img, band])
    joined
  end
end
