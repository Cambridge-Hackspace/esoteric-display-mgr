defmodule EsotericDisplayMgr.Repo do
  use Ecto.Repo,
    otp_app: :esoteric_display_mgr,
    adapter: Ecto.Adapters.SQLite3
end
