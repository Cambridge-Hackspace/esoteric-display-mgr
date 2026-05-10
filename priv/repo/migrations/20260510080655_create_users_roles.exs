defmodule EsotericDisplayMgr.Repo.Migrations.CreateUsersRoles do
  use Ecto.Migration

  def change do
    create table(:users_roles, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all), primary_key: true
      add :role_id, references(:roles, on_delete: :delete_all), primary_key: true
    end

    create index(:users_roles, [:user_id])
    create index(:users_roles, [:role_id])

    drop index(:users, [:role_id])

    alter table(:users) do
      remove :role_id
    end
  end
end
