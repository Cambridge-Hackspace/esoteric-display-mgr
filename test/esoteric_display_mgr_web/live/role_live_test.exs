defmodule EsotericDisplayMgrWeb.RoleLiveTest do
  use EsotericDisplayMgrWeb.ConnCase

  import Phoenix.LiveViewTest
  import EsotericDisplayMgr.AccountsFixtures

  @create_attrs %{name: "some name", permissions: ["option1", "option2"]}
  @update_attrs %{name: "some updated name", permissions: ["option1"]}
  @invalid_attrs %{name: nil, permissions: []}

  setup :register_and_log_in_user

  defp create_role(%{scope: scope}) do
    role = role_fixture(scope)

    %{role: role}
  end

  describe "Index" do
    setup [:create_role]

    test "lists all roles", %{conn: conn, role: role} do
      {:ok, _index_live, html} = live(conn, ~p"/roles")

      assert html =~ "Listing Roles"
      assert html =~ role.name
    end

    test "saves new role", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/roles")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Role")
               |> render_click()
               |> follow_redirect(conn, ~p"/roles/new")

      assert render(form_live) =~ "New Role"

      assert form_live
             |> form("#role-form", role: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#role-form", role: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/roles")

      html = render(index_live)
      assert html =~ "Role created successfully"
      assert html =~ "some name"
    end

    test "updates role in listing", %{conn: conn, role: role} do
      {:ok, index_live, _html} = live(conn, ~p"/roles")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#roles-#{role.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/roles/#{role}/edit")

      assert render(form_live) =~ "Edit Role"

      assert form_live
             |> form("#role-form", role: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#role-form", role: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/roles")

      html = render(index_live)
      assert html =~ "Role updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes role in listing", %{conn: conn, role: role} do
      {:ok, index_live, _html} = live(conn, ~p"/roles")

      assert index_live |> element("#roles-#{role.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#roles-#{role.id}")
    end
  end

  describe "Show" do
    setup [:create_role]

    test "displays role", %{conn: conn, role: role} do
      {:ok, _show_live, html} = live(conn, ~p"/roles/#{role}")

      assert html =~ "Show Role"
      assert html =~ role.name
    end

    test "updates role and returns to show", %{conn: conn, role: role} do
      {:ok, show_live, _html} = live(conn, ~p"/roles/#{role}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/roles/#{role}/edit?return_to=show")

      assert render(form_live) =~ "Edit Role"

      assert form_live
             |> form("#role-form", role: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#role-form", role: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/roles/#{role}")

      html = render(show_live)
      assert html =~ "Role updated successfully"
      assert html =~ "some updated name"
    end
  end
end
