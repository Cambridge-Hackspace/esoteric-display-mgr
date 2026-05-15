defmodule EsotericDisplayMgr.Media.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_items" do
    field :media_type, Ecto.Enum, values: [:image, :gif, :text]
    field :content, :string
    field :marquee, Ecto.Enum, values: [:none, :ltr, :rtl, :utd, :dtu], default: :none
    field :sizing, Ecto.Enum, values: [:stretch, :zoom, :crop], default: :stretch
    field :protected, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc """
  Generates a changeset. If `can_protect?` is true, the user is allowed
  to modify the `protected` flag.
  """
  def changeset(item, attrs, can_protect? \\ false) do
    item
    |> cast(attrs, [:media_type, :content, :marquee, :sizing])
    |> validate_required([:media_type, :content, :marquee, :sizing])
    |> maybe_cast_protected(attrs, can_protect?)
  end

  defp maybe_cast_protected(changeset, attrs, true) do
    cast(changeset, attrs, [:protected])
  end

  defp maybe_cast_protected(changeset, _attrs, false) do
    changeset
  end
end
