# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     EsotericDisplayMgr.Repo.insert!(%EsotericDisplayMgr.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias EsotericDisplayMgr.Repo
alias EsotericDisplayMgr.Accounts.{Role, User, Permissions}

IO.puts("Seeding the database...")

# 1. Create the roles.

roles_data = [
  %{
    name: "Admin",
    permissions: Permissions.all()
  },
  %{
    name: "Display Manager",
    permissions: [
      "displays:manage",
      "displays:list",
      "stream:connect",
      "stream:manage",
      "priority:manage"
    ]
  },
  %{
    name: "Content Manager",
    permissions: [
      "displays:list",
      "media:manage",
      "media:protect"
    ]
  },
  %{
    name: "Content Editor",
    permissions: [
      "displays:list",
      "media:manage"
    ]
  },
  %{
    name: "Streamer",
    permissions: [
      "displays:list",
      "stream:connect"
    ]
  }
]

roles =
  Enum.into(roles_data, %{}, fn role_attrs ->
    case Repo.get_by(Role, name: role_attrs.name) do
      nil ->
        {:ok, role} =
          %Role{}
          |> Role.changeset(role_attrs)
          |> Repo.insert()

        {role_attrs.name, role}

      role ->
        {role_attrs.name, role}
    end
  end)

IO.puts("Roles seeded.")

# 2. Create the primary admin user.

admin_email = "admin@chack.local"

if Repo.get_by(User, email: admin_email) == nil do
  admin_role = roles["Admin"]

  {:ok, _admin} =
    %User{}
    |> Repo.preload(:roles)
    |> User.registration_changeset(%{
      "email" => admin_email
    })
    |> Ecto.Changeset.put_assoc(:roles, [admin_role])
    |> Ecto.Changeset.put_change(:confirmed_at, DateTime.utc_now(:second))
    |> Repo.insert()

  IO.puts("Primary admin user created: #{admin_email}")
else
  IO.puts("Primary admin user already exists.")
end

IO.puts("Seeding complete!")
