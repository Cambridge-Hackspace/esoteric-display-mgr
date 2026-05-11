defmodule EsotericDisplayMgr.Hardware.Display do
  use Ecto.Schema
  import Ecto.Changeset

  schema "displays" do
    field :label, :string
    field :ip_address, :string
    field :port, :integer
    field :width, :integer
    field :height, :integer
    field :color_type, :string
    field :bits_per_channel, :integer
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(display, attrs, user_scope) do
    display
    |> cast(attrs, [:label, :ip_address, :port, :width, :height, :color_type, :bits_per_channel])
    |> validate_required([
      :label,
      :ip_address,
      :port,
      :width,
      :height,
      :color_type,
      :bits_per_channel
    ])
    |> unique_constraint(:label)
    |> validate_inclusion(:color_type, ["RGB", "RGBW", "HSL", "Grayscale"])
    |> validate_number(:port, greater_than: 0, less_than: 65536)
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_number(:bits_per_channel, [1, 4, 8, 16, 24, 32])
    |> put_change(:user_id, user_scope.user.id)
  end
end
