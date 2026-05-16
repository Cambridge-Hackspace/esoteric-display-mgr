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

  @doc """
  Encodes payload data into a DDP packet.

  Options:
  - `:sequence` (0-15, default 0)
  - `:type` (e.g. :rgb, :grayscale, default: :rgb)
  - `:bit` (bits per channel: 1, 4, 8, 16, 23, 32, default 8)
  - `:dest_id` (0-255, default 0)
  - `:offset` (32-bit integer, default 0)
  - `:push` (boolean, default true)
  """
  def encode(payload, opts \\ []) do
    sequence = Keyword.get(opts, :sequence, 0) &&& 0x0F
    dest_id = Keyword.get(opts, :dest_id, 0)
    offset = Keyword.get(opts, :offset, 0)
    push? = Keyword.get(opts, :push, true)

    type_atom = Keyword.get(opts, :type, :rgb)
    bits = Keyword.get(opts, :bits, 8)

    type_byte = encode_type(type_atom, bits)
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
        {type, bits} = decode_type(type_byte)

        {:ok,
         %{
           push?: (flags &&& @flag_push) != 0,
           query?: (flags &&& @flag_query) != 0,
           reply?: (flags &&& @flag_reply) != 0,
           storage?: (flags &&& @flag_storage) != 0,
           timecode?: (flags &&& @flag_timecode) != 0,
           sequence: sequence,
           type: type,
           bits: bits,
           dest_id: dest_id,
           offset: offset,
           length: length,
           payload: binary_part(payload, 0, length)
         }}
    end
  end

  def decode(_), do: {:error, :malformed_packet}

  defp encode_type(:control, _), do: 0x0A

  defp encode_type(type, bits) do
    ttt =
      case type do
        :rgb -> 1
        :hsl -> 2
        :rgbw -> 3
        :grayscale -> 4
        _ -> 0
      end

    sss =
      case bits do
        1 -> 1
        4 -> 2
        8 -> 3
        16 -> 4
        24 -> 5
        32 -> 6
        _ -> 0
      end

    ttt <<< 3 ||| sss
  end

  defp decode_type(0x0A), do: {:control, 0}

  defp decode_type(byte) do
    ttt = byte >>> 3 &&& 0b111
    sss = byte &&& 0b111

    type =
      case ttt do
        1 -> :rgb
        2 -> :hsl
        3 -> :rgbw
        4 -> :grayscale
        _ -> :undefined
      end

    bits =
      case sss do
        1 -> 1
        2 -> 4
        4 -> 8
        5 -> 24
        6 -> 32
        _ -> 0
      end

    {type, bits}
  end
end
