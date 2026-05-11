defmodule EsotericDisplayMgrWeb.DisplayLiveTest do
  use EsotericDisplayMgrWeb.ConnCase

  import Phoenix.LiveViewTest
  import EsotericDisplayMgr.HardwareFixtures

  @create_attrs %{
    label: "some label",
    port: 42,
    width: 42,
    ip_address: "some ip_address",
    height: 42,
    color_type: "some color_type",
    bits_per_channel: 42
  }
  @update_attrs %{
    label: "some updated label",
    port: 43,
    width: 43,
    ip_address: "some updated ip_address",
    height: 43,
    color_type: "some updated color_type",
    bits_per_channel: 43
  }
  @invalid_attrs %{
    label: nil,
    port: nil,
    width: nil,
    ip_address: nil,
    height: nil,
    color_type: nil,
    bits_per_channel: nil
  }

  setup :register_and_log_in_user

  defp create_display(%{scope: scope}) do
    display = display_fixture(scope)

    %{display: display}
  end

  describe "Index" do
    setup [:create_display]

    test "lists all displays", %{conn: conn, display: display} do
      {:ok, _index_live, html} = live(conn, ~p"/displays")

      assert html =~ "Listing Displays"
      assert html =~ display.label
    end

    test "saves new display", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/displays")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Display")
               |> render_click()
               |> follow_redirect(conn, ~p"/displays/new")

      assert render(form_live) =~ "New Display"

      assert form_live
             |> form("#display-form", display: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#display-form", display: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/displays")

      html = render(index_live)
      assert html =~ "Display created successfully"
      assert html =~ "some label"
    end

    test "updates display in listing", %{conn: conn, display: display} do
      {:ok, index_live, _html} = live(conn, ~p"/displays")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#displays-#{display.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/displays/#{display}/edit")

      assert render(form_live) =~ "Edit Display"

      assert form_live
             |> form("#display-form", display: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#display-form", display: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/displays")

      html = render(index_live)
      assert html =~ "Display updated successfully"
      assert html =~ "some updated label"
    end

    test "deletes display in listing", %{conn: conn, display: display} do
      {:ok, index_live, _html} = live(conn, ~p"/displays")

      assert index_live |> element("#displays-#{display.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#displays-#{display.id}")
    end
  end

  describe "Show" do
    setup [:create_display]

    test "displays display", %{conn: conn, display: display} do
      {:ok, _show_live, html} = live(conn, ~p"/displays/#{display}")

      assert html =~ "Show Display"
      assert html =~ display.label
    end

    test "updates display and returns to show", %{conn: conn, display: display} do
      {:ok, show_live, _html} = live(conn, ~p"/displays/#{display}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/displays/#{display}/edit?return_to=show")

      assert render(form_live) =~ "Edit Display"

      assert form_live
             |> form("#display-form", display: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#display-form", display: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/displays/#{display}")

      html = render(show_live)
      assert html =~ "Display updated successfully"
      assert html =~ "some updated label"
    end
  end
end
