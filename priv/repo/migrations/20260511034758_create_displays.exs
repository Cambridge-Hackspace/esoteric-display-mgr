defmodule EsotericDisplayMgr.Repo.Migrations.CreateDisplays do
  use Ecto.Migration

  def change do
    create table(:displays) do
      add :label, :string
      add :ip_address, :string
      add :port, :integer
      add :width, :integer
      add :height, :integer
      add :color_type, :string
      add :bits_per_channel, :integer
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:displays, [:user_id])

    create unique_index(:displays, [:label])
  end
end
