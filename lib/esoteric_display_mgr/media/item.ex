defmodule EsotericDisplayMgr.Media.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_items" do
    field :media_type, Ecto.Enum, values: [:image, :gif, :text]
    field :content, :string
    field :marquee, Ecto.Enum, values: [:none, :ltr, :rtl, :utd, :dtu], default: :none
    field :sizing, Ecto.Enum, values: [:stretch, :zoom, :crop], default: :stretch
    field :protected, :boolean, default: false
    field :priority, :integer, default: 7

    many_to_many :displays, EsotericDisplayMgr.Hardware.Display,
      join_through: "media_items_displays",
      join_keys: [media_item_id: :id, display_id: :id],
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc """
  Generates a changeset. If `can_protect?` is true, the user is allowed
  to modify the `protected` flag.
  """
  def changeset(item, attrs, user_priority_cap, can_protect? \\ false) do
    item
    |> cast(attrs, [:media_type, :content, :marquee, :sizing, :priority])
    |> validate_required([:media_type, :content, :marquee, :sizing, :priority])
    |> validate_inclusion(:priority, 0..7)
    |> validate_priority(user_priority_cap)
    |> maybe_cast_protected(attrs, can_protect?)
  end

  defp validate_priority(changeset, user_priority_cap) do
    case get_change(changeset, :priority) do
      nil ->
        changeset

      new_priority ->
        if new_priority >= user_priority_cap do
          changeset
        else
          add_error(
            changeset,
            :priority,
            "cannot set priority higher than your cap (#{user_priority_cap})"
          )
        end
    end
  end

  defp maybe_cast_protected(changeset, attrs, true) do
    cast(changeset, attrs, [:protected])
  end

  defp maybe_cast_protected(changeset, _attrs, false) do
    changeset
  end
end
