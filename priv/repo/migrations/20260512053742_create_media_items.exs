defmodule EsotericDisplayMgr.Repo.Migrations.CreateMediaItems do
  use Ecto.Migration

  def change do
    create table(:media_items) do
      add :media_type, :string, null: false
      add :content, :text, null: false
      add :marquee, :string, null: false, default: "none"
      add :sizing, :string, null: false, default: "stretch"
      add :protected, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
