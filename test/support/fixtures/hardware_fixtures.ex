defmodule EsotericDisplayMgr.HardwareFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `EsotericDisplayMgr.Hardware` context.
  """

  @doc """
  Generate a unique display label.
  """
  def unique_display_label, do: "some label#{System.unique_integer([:positive])}"

  @doc """
  Generate a display.
  """
  def display_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        bits_per_channel: 42,
        color_type: "some color_type",
        height: 42,
        ip_address: "some ip_address",
        label: unique_display_label(),
        port: 42,
        width: 42
      })

    {:ok, display} = EsotericDisplayMgr.Hardware.create_display(scope, attrs)
    display
  end
end
