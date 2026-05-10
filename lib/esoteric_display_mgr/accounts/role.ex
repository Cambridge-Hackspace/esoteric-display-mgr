defmodule EsotericDisplayMgr.Accounts.Role do
  use Ecto.Schema
  import Ecto.Changeset
  alias EsotericDisplayMgr.Accounts.Permissions

  schema "roles" do
    field :name, :string
    field :permissions, {:array, :string}, default: []

    many_to_many :users, EsotericDisplayMgr.Accounts.User, join_through: "users_roles"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :permissions])
    |> validate_required([:name, :permissions])
    |> unique_constraint(:name)
    |> validate_permissions()
  end

  defp validate_permissions(changeset) do
    permissions = get_field(changeset, :permissions) || []
    invalid_permissions = Enum.reject(permissions, &Permissions.valid?/1)

    if Enum.empty?(invalid_permissions) do
      changeset
    else
      add_error(
        changeset,
        :permissions,
        "contains invalid permissions: #{inspect(invalid_permissions)}"
      )
    end
  end
end
