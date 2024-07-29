defmodule WsWeb.Router do
  use WsWeb, :router

  @content_security_policy "frame-ancestors 'self'; base-uri 'self'; default-src 'self'; script-src 'self' 'unsafe-eval' 'unsafe-inline'; connect-src 'self' ws wss https://picsum.photos/300/300.jpg https://fastly.picsum.photos ;img-src 'self' data: blob:;style-src 'self' 'unsafe-inline';font-src 'self';form-action 'self';"

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WsWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers,
         %{"content-security-policy" => @content_security_policy}
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", WsWeb do
    pipe_through :browser

    # get "/", PageController, :home
    live "/", MainLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", WsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:ws, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WsWeb.Telemetry
    end
  end
end
