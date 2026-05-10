defmodule EsotericDisplayMgr.Repo.Migrations.CreateRolesAndUpdateUsers do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :name, :string, null: false
      add :permissions, :json, null: false, default: "[]"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:roles, [:name])

    alter table(:users) do
      # remove the old string column
      remove :role
      add :role_id, references(:roles, on_delete: :nilify_all)
    end

    create index(:users, [:role_id])
  end
end
