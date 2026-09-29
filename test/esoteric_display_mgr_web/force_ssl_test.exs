defmodule EsotericDisplayMgrWeb.ForceSSLTest do
  # Not async: these change the application environment, which is global.
  use ExUnit.Case, async: false

  alias EsotericDisplayMgrWeb.ForceSSL

  setup do
    previous = Application.fetch_env(:esoteric_display_mgr, :ssl_exclude_hosts)

    on_exit(fn ->
      case previous do
        {:ok, hosts} -> Application.put_env(:esoteric_display_mgr, :ssl_exclude_hosts, hosts)
        :error -> Application.delete_env(:esoteric_display_mgr, :ssl_exclude_hosts)
      end
    end)

    :ok
  end

  test "with nothing configured, only this machine is let off" do
    Application.delete_env(:esoteric_display_mgr, :ssl_exclude_hosts)

    assert ForceSSL.excluded?("localhost")
    assert ForceSSL.excluded?("127.0.0.1")
    refute ForceSSL.excluded?("edm.example.org")
  end

  test "the configured list replaces the default rather than adding to it" do
    Application.put_env(:esoteric_display_mgr, :ssl_exclude_hosts, ["edm.example.org"])

    assert ForceSSL.excluded?("edm.example.org")
    refute ForceSSL.excluded?("localhost")
  end

  test "an empty list means every host is redirected" do
    Application.put_env(:esoteric_display_mgr, :ssl_exclude_hosts, [])

    refute ForceSSL.excluded?("localhost")
    refute ForceSSL.excluded?("127.0.0.1")
  end

  test "a host is matched whole, not as part of a longer name" do
    Application.put_env(:esoteric_display_mgr, :ssl_exclude_hosts, ["edm.example.org"])

    refute ForceSSL.excluded?("evil-edm.example.org")
    refute ForceSSL.excluded?("edm.example.org.attacker.test")
  end

  test "the production endpoint is wired to this function" do
    # The point of the module is that no host list is baked in at compile
    # time, so check the compile-time config says so.
    config = Config.Reader.read!("config/prod.exs", env: :prod)
    force_ssl = config[:esoteric_display_mgr][EsotericDisplayMgrWeb.Endpoint][:force_ssl]

    assert force_ssl[:exclude] == {ForceSSL, :excluded?, []}
  end
end
