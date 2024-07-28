defmodule WsWeb.PageController do
  use WsWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    token = Phoenix.Token.sign(WsWeb.Endpoint, "user socket", "user_id")

    render(conn, :home, layout: false, token: token)
  end
end
