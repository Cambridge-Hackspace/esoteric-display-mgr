defmodule EsotericDisplayMgrWeb.Router do
  use EsotericDisplayMgrWeb, :router

  import EsotericDisplayMgrWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EsotericDisplayMgrWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug EsotericDisplayMgrWeb.Plugs.ApiAuth
  end

  scope "/", EsotericDisplayMgrWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api", EsotericDisplayMgrWeb do
    pipe_through :api_auth

    get "/displays", API.StreamController, :index
    post "/streams", API.StreamController, :create
    delete "/streams/:port", API.StreamController, :delete

    get "/media", API.MediaController, :index
    post "/media", API.MediaController, :create
    delete "/media/:id", API.MediaController, :delete
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:esoteric_display_mgr, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: EsotericDisplayMgrWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", EsotericDisplayMgrWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{EsotericDisplayMgrWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    live_session :manage_users,
      on_mount: [
        {EsotericDisplayMgrWeb.UserAuth, :require_authenticated},
        {EsotericDisplayMgrWeb.UserAuth, {:require_permission, "users:manage"}}
      ] do
      live "/admin/users", UserLive.Index, :index
      live "/admin/users/new", UserLive.Form, :new
      live "/admin/users/:id/edit", UserLive.Form, :edit
    end

    live_session :manage_roles,
      on_mount: [
        {EsotericDisplayMgrWeb.UserAuth, :require_authenticated},
        {EsotericDisplayMgrWeb.UserAuth, {:require_permission, "roles:manage"}}
      ] do
      live "/admin/roles", RoleLive.Index, :index
      live "/admin/roles/new", RoleLive.Form, :new
      live "/admin/roles/:id/edit", RoleLive.Form, :edit
    end

    live_session :manage_displays,
      on_mount: [
        {EsotericDisplayMgrWeb.UserAuth, :require_authenticated},
        {EsotericDisplayMgrWeb.UserAuth, {:require_permission, "displays:manage"}}
      ] do
      live "/admin/displays", DisplayLive.Index, :index
      live "/admin/displays/new", DisplayLive.Form, :new
      live "/admin/displays/:id/edit", DisplayLive.Form, :edit
      live "/admin/displays/:id", DisplayLive.Show, :show
      live "/admin/displays/:id/show/edit", DisplayLive.Form, :edit
    end

    live_session :manage_streams,
      on_mount: [
        {EsotericDisplayMgrWeb.UserAuth, :require_authenticated},
        {EsotericDisplayMgrWeb.UserAuth, {:require_permission, "stream:connect"}}
      ] do
      live "/admin/streams", StreamLive.Index, :index
    end

    live_session :manage_media,
      on_mount: [
        {EsotericDisplayMgrWeb.UserAuth, :require_authenticated},
        {EsotericDisplayMgrWeb.UserAuth, {:require_permission, "media:manage"}}
      ] do
      live "/admin/media", MediaLive.Index, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", EsotericDisplayMgrWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{EsotericDisplayMgrWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
