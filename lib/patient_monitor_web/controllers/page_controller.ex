defmodule PatientMonitorWeb.PageController do
  use PatientMonitorWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
