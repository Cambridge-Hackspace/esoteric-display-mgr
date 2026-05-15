defmodule EsotericDisplayMgr.Stream.DDP do
  @moduledoc """
  Distributed Display Protocol (DDP) implementation.
  """
  import Bitwise

  # Protocol Version
  @version1 0x40

  # Header Flags
  @flag_timecode 0x10
  @flag_storage 0x08
  @flag_reply 0x04
  @flag_query 0x02
  @flag_push 0x01

  # Data Types
  @type_undefined 0x00
  @type_rgb24 0x01
  @type_hsl 0x02
  @type_rgbw32 0x03
  @type_grayscale 0x04
  @type_control 0x0A

  @doc """
  Encodes payload data into a DDP packet.

  Options:
  - `:sequence` (0-15, default 0)
  - `:type` (e.g. :rgb24, :grayscale, default: rgb24)
  - `:dest_id` (0-255, default 0)
  - `:offset` (32-bit integer, default 0)
  - `:push` (boolean, default true)
  """
  def encode(payload, opts \\ []) do
    sequence = Keyword.get(opts, :sequence, 0) &&& 0x0F
    dest_id = Keyword.get(opts, :dest_id, 0)
    offset = Keyword.get(opts, :offset, 0)
    push? = Keyword.get(opts, :push, true)

    type_byte = encode_type(Keyword.get(opts, :type, :rgb24))
    flags = @version1
    flags = if push?, do: flags ||| @flag_push, else: flags

    length = byte_size(payload)

    <<
      flags::8,
      sequence::8,
      type_byte::8,
      dest_id::8,
      offset::32,
      length::16
    >> <> payload
  end

  @doc """
  Decodes a binary DDP packet into a map.
  """
  def decode(
        <<flags::8, sequence::8, type_byte::8, dest_id::8, offset::32, length::16,
          payload::binary>>
      ) do
    cond do
      (flags &&& 0xC0) != @version1 ->
        {:error, :invalid_version}

      byte_size(payload) < length ->
        {:error, :payload_too_short}

      true ->
        {:ok,
         %{
           push?: (flags &&& @flag_push) != 0,
           query?: (flags &&& @flag_query) != 0,
           reply?: (flags &&& @flag_reply) != 0,
           storage?: (flags &&& @flag_storage) != 0,
           timecode?: (flags &&& @flag_timecode) != 0,
           sequence: sequence,
           type: decode_type(type_byte),
           dest_id: dest_id,
           offset: offset,
           length: length,
           payload: binary_part(payload, 0, length)
         }}
    end
  end

  def decode(_), do: {:error, :malformed_packet}

  defp encode_type(:rgb24), do: @type_rgb24
  defp encode_type(:hsl), do: @type_hsl
  defp encode_type(:rgbw32), do: @type_rgbw32
  defp encode_type(:grayscale), do: @type_grayscale
  defp encode_type(:control), do: @type_control
  defp encode_type(_), do: @type_undefined

  defp decode_type(@type_rgb24), do: :rgb24
  defp decode_type(@type_hsl), do: :hsl
  defp decode_type(@type_rgbw32), do: :rgbw32
  defp decode_type(@type_grayscale), do: :grayscale
  defp decode_type(@type_control), do: :control
  defp decode_type(_), do: :undefined
end
