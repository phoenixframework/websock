defmodule WebSockTest do
  use ExUnit.Case, async: true

  test "upgrades Cowboy connections and handles all options" do
    opts = [compress: true, timeout: 1, max_frame_size: 2, fullsweep_after: 3, other: :ok]

    %Plug.Conn{adapter: {Plug.Cowboy.Conn, adapter}} =
      WebSock.upgrade(%Plug.Conn{adapter: {Plug.Cowboy.Conn, %{}}}, :sock, :arg, opts)

    assert adapter.upgrade ==
             {:websocket,
              {WebSock.CowboyAdapter, {:sock, %{fullsweep_after: 3}, :arg},
               %{compress: true, idle_timeout: 1, max_frame_size: 2}}}
  end

  test "raises an error on unknown adapter upgrade requests" do
    assert_raise ArgumentError, "Unknown adapter OtherServer", fn ->
      WebSock.upgrade(%Plug.Conn{adapter: {OtherServer, %{}}}, :sock, :arg, [])
    end
  end
end
