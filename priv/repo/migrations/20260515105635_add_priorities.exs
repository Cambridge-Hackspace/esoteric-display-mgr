defmodule EsotericDisplayMgr.Repo.Migrations.AddPriorities do
  use Ecto.Migration

  def change do
    alter table(:displays) do
      add :required_priority, :integer, default: 7, null: false
    end

    alter table(:media_items) do
      add :priority, :integer, default: 7, null: false
    end

    create table(:media_items_displays) do
      add :media_item_id, references(:media_items, on_delete: :delete_all), null: false
      add :display_id, references(:displays, on_delete: :delete_all), null: false
    end

    create index(:media_items_displays, [:media_item_id])
    create index(:media_items_displays, [:display_id])
    create unique_index(:media_items_displays, [:media_item_id, :display_id])
  end
end
