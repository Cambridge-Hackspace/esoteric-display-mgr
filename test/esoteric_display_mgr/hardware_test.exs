defmodule EsotericDisplayMgr.HardwareTest do
  use EsotericDisplayMgr.DataCase

  alias EsotericDisplayMgr.Hardware

  describe "displays" do
    alias EsotericDisplayMgr.Hardware.Display

    import EsotericDisplayMgr.AccountsFixtures, only: [user_scope_fixture: 0]
    import EsotericDisplayMgr.HardwareFixtures

    @invalid_attrs %{
      label: nil,
      port: nil,
      width: nil,
      ip_address: nil,
      height: nil,
      color_type: nil,
      bits_per_channel: nil
    }

    test "list_displays/1 returns all scoped displays" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      display = display_fixture(scope)
      other_display = display_fixture(other_scope)
      assert Hardware.list_displays(scope) == [display]
      assert Hardware.list_displays(other_scope) == [other_display]
    end

    test "get_display!/2 returns the display with given id" do
      scope = user_scope_fixture()
      display = display_fixture(scope)
      other_scope = user_scope_fixture()
      assert Hardware.get_display!(scope, display.id) == display
      assert_raise Ecto.NoResultsError, fn -> Hardware.get_display!(other_scope, display.id) end
    end

    test "create_display/2 with valid data creates a display" do
      valid_attrs = %{
        label: "some label",
        port: 42,
        width: 42,
        ip_address: "some ip_address",
        height: 42,
        color_type: "some color_type",
        bits_per_channel: 42
      }

      scope = user_scope_fixture()

      assert {:ok, %Display{} = display} = Hardware.create_display(scope, valid_attrs)
      assert display.label == "some label"
      assert display.port == 42
      assert display.width == 42
      assert display.ip_address == "some ip_address"
      assert display.height == 42
      assert display.color_type == "some color_type"
      assert display.bits_per_channel == 42
      assert display.user_id == scope.user.id
    end

    test "create_display/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Hardware.create_display(scope, @invalid_attrs)
    end

    test "update_display/3 with valid data updates the display" do
      scope = user_scope_fixture()
      display = display_fixture(scope)

      update_attrs = %{
        label: "some updated label",
        port: 43,
        width: 43,
        ip_address: "some updated ip_address",
        height: 43,
        color_type: "some updated color_type",
        bits_per_channel: 43
      }

      assert {:ok, %Display{} = display} = Hardware.update_display(scope, display, update_attrs)
      assert display.label == "some updated label"
      assert display.port == 43
      assert display.width == 43
      assert display.ip_address == "some updated ip_address"
      assert display.height == 43
      assert display.color_type == "some updated color_type"
      assert display.bits_per_channel == 43
    end

    test "update_display/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      display = display_fixture(scope)

      assert_raise MatchError, fn ->
        Hardware.update_display(other_scope, display, %{})
      end
    end

    test "update_display/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      display = display_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Hardware.update_display(scope, display, @invalid_attrs)
      assert display == Hardware.get_display!(scope, display.id)
    end

    test "delete_display/2 deletes the display" do
      scope = user_scope_fixture()
      display = display_fixture(scope)
      assert {:ok, %Display{}} = Hardware.delete_display(scope, display)
      assert_raise Ecto.NoResultsError, fn -> Hardware.get_display!(scope, display.id) end
    end

    test "delete_display/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      display = display_fixture(scope)
      assert_raise MatchError, fn -> Hardware.delete_display(other_scope, display) end
    end

    test "change_display/2 returns a display changeset" do
      scope = user_scope_fixture()
      display = display_fixture(scope)
      assert %Ecto.Changeset{} = Hardware.change_display(scope, display)
    end
  end
end
