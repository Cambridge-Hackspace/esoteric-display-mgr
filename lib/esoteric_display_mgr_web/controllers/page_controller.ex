defmodule EsotericDisplayMgrWeb.PageController do
  use EsotericDisplayMgrWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
