defmodule EsotericDisplayMgr.RuntimeConfigTest do
  # Not async: these change environment variables, which are global.
  use ExUnit.Case, async: false

  @endpoint_key EsotericDisplayMgrWeb.Endpoint

  @settable ~w(PHX_HOST PHX_URL_PORT PHX_URL_SCHEME PHX_BIND PHX_SSL_EXCLUDE_HOSTS
               PORT DATABASE_PATH SECRET_KEY_BASE PHX_SERVER)

  setup do
    previous = Map.new(@settable, &{&1, System.get_env(&1)})

    on_exit(fn ->
      Enum.each(previous, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)
    end)

    Enum.each(@settable, &System.delete_env/1)
    System.put_env("DATABASE_PATH", "/tmp/edm-test.db")
    System.put_env("SECRET_KEY_BASE", String.duplicate("x", 64))
    :ok
  end

  defp prod_config(env \\ []) do
    Enum.each(env, fn {name, value} -> System.put_env(name, value) end)
    Config.Reader.read!("config/runtime.exs", env: :prod)[:esoteric_display_mgr]
  end

  defp endpoint(env \\ []), do: prod_config(env)[@endpoint_key]

  describe "with only the required settings" do
    test "the public address is https on 443" do
      url = endpoint()[:url]

      assert url[:scheme] == "https"
      assert url[:port] == 443
    end

    test "it listens on the IPv6 wildcard" do
      assert endpoint()[:http][:ip] == {0, 0, 0, 0, 0, 0, 0, 0}
    end

    test "only this machine is let off the https redirect" do
      assert prod_config()[:ssl_exclude_hosts] == ["localhost", "127.0.0.1"]
    end
  end

  describe "the public address" do
    test "takes its host from PHX_HOST" do
      assert endpoint([{"PHX_HOST", "edm.chack.internal"}])[:url][:host] == "edm.chack.internal"
    end

    test "takes its port and scheme from the environment" do
      url = endpoint([{"PHX_URL_PORT", "4000"}, {"PHX_URL_SCHEME", "http"}])[:url]

      assert url[:port] == 4000
      assert url[:scheme] == "http"
    end
  end

  describe "PHX_BIND" do
    test "accepts an IPv4 address" do
      assert endpoint([{"PHX_BIND", "0.0.0.0"}])[:http][:ip] == {0, 0, 0, 0}
      assert endpoint([{"PHX_BIND", "127.0.0.1"}])[:http][:ip] == {127, 0, 0, 1}
    end

    test "accepts an IPv6 address" do
      assert endpoint([{"PHX_BIND", "::1"}])[:http][:ip] == {0, 0, 0, 0, 0, 0, 0, 1}
    end

    test "refuses something that is not an address, and says which setting" do
      # A hostname here would otherwise surface much later as an obscure
      # failure to open the socket.
      error = assert_raise RuntimeError, fn -> endpoint([{"PHX_BIND", "localhost"}]) end

      assert error.message =~ "PHX_BIND"
      assert error.message =~ "localhost"
    end
  end

  describe "PHX_SSL_EXCLUDE_HOSTS" do
    test "is a comma-separated list" do
      config = prod_config([{"PHX_SSL_EXCLUDE_HOSTS", "edm.example.org,127.0.0.1"}])

      assert config[:ssl_exclude_hosts] == ["edm.example.org", "127.0.0.1"]
    end

    test "forgives spaces and stray commas" do
      config = prod_config([{"PHX_SSL_EXCLUDE_HOSTS", " edm.example.org , ,127.0.0.1,"}])

      assert config[:ssl_exclude_hosts] == ["edm.example.org", "127.0.0.1"]
    end
  end

  test "the listening port still comes from PORT" do
    assert endpoint([{"PORT", "4321"}])[:http][:port] == 4321
  end
end
