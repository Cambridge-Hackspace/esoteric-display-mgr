defmodule EsotericDisplayMgrWeb.ForceSSL do
  @moduledoc """
  Decides which hosts may be reached over plain http.

  `Plug.SSL` redirects everything to https unless told otherwise, and Phoenix
  reads its options when the endpoint is compiled. The hosts to leave alone
  depend on where the app is running, which is not known until it starts, so
  the endpoint is given this function instead of a list.
  """

  @default ["localhost", "127.0.0.1"]

  @doc """
  Whether requests for `host` are exempt from the redirect to https.

  The list is `:ssl_exclude_hosts` in the application environment, set from
  `PHX_SSL_EXCLUDE_HOSTS` in `config/runtime.exs`.
  """
  def excluded?(host) when is_binary(host) do
    host in Application.get_env(:esoteric_display_mgr, :ssl_exclude_hosts, @default)
  end
end
