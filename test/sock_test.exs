defmodule SockTest do
  use ExUnit.Case
  doctest Sock

  test "greets the world" do
    assert Sock.hello() == :world
  end
end
