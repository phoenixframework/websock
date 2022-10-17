# Sock

[![Build Status](https://github.com/mtrudel/sock/workflows/Elixir%20CI/badge.svg)](https://github.com/mtrudel/sock/actions)
[![Docs](https://img.shields.io/badge/api-docs-green.svg?style=flat)](https://hexdocs.pm/sock)
[![Hex.pm](https://img.shields.io/hexpm/v/sock.svg?style=flat&color=blue)](https://hex.pm/packages/sock)


Sock is a specification for apps to service WebSocket connections; you can think
of it as 'Plug for WebSockets'. Web servers such as
[Bandit](https://github.com/mtrudel/bandit/) or
[Cowboy](https://github.com/ninenines/cowboy) are expected to implement support
for hosting Sock-based applications (possibly by way of an adapter library such
as [Plug.Cowboy](https://github.com/elixir-plug/plug_cowboy/)). WebSocket-aware
applications such as Phoenix can then be hosted within a supported web server
simply by defining conformance to the `Sock` behaviour, in the same manner as
how Plug conformance allows their HTTP aspects to be hosted within an arbitrary
web server.

The Sock specification is just that; a specification. There is no actual *code*
in this specification as there is within the Plug specification, largely due to
the lower-level nature of WebSockets as compared to HTTP. What you *will* find
here consists of simple interface which dictates conventions about how the
lifecycle of a WebSocket connection is managed.

The `Sock` behaviour describes the functions that an application must
implement in order to be Sock compliant; it is the equivalent of the `Plug`
interface, but for WebSocket connections. Server implementations are expected
to manage the upgrade process to WebSocket connections themselves, based on
their specific policy and routing decisions and aided by helper functions within
the Plug API (see below for details).

## WebSocket Lifecycle

WebSocket connections go through a well defined lifecycle, which is reflected in
the shape of the `Sock` behaviour:

* **This step is outside the scope of the Sock API**. A client will
  attempt to Upgrade an HTTP connection to a WebSocket connection by passing
  a specific set of headers in an HTTP request. An application may choose to
  determine the feasibility of the upgrade request however it pleases, though
  the `Plug.WebSocket` module includes several conveniences for this purpose.
  Most typically, an application will then signal an upgrade to be performed by
  calling the `Plug.Conn.upgrade_adapter/3` callback with parameters indicating
  an upgrade to Sock (note that the structure of these arguments depends on the
  particular server in use; consult `Bandit` or `Plug.Cowboy` documentation for
  details)
* Assuming the application accepted the WebSocket connection, the underlying
  server will then upgrade the HTTP connection to a WebSocket connection, and
  will call `c:Sock.init/1` to allow the application to perform any necessary
  tasks now that the WebSocket connection is live
* The `Sock` implementation will be notified of client data by way of the
  `c:Sock.handle_in/2` callback
* The `Sock` implementation may choose to be notified of control frames by way of the
  optional `c:Sock.handle_control/2` callback. Note that user implementations DO
  NOT need to concern themselves with issuing pong frames in response to ping
  requests; the underlying server implementation MUST handle this
* The `Sock` implementation will be notified of any messages sent to it by
  other processes by way of the `c:Sock.handle_info/2` callback
* The `Sock` implementation can send data to the client by returning
  a `{:push,...}` tuple from any of the above `handle_*` callback
* At any time, `c:Sock.terminate/2` may be called to indicate a close, error or
  timeout condition 

For more information, consult the [docs](https://hexdocs.pm/sock).

## Installation

The sock package can be installed by adding `sock` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sock, "~> 0.3.0"}
  ]
end
```

Documentation can be found at <https://hexdocs.pm/sock>.

## License

MIT
