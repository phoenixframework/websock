# WebSock

[![Build Status](https://github.com/mtrudel/websock/workflows/Elixir%20CI/badge.svg)](https://github.com/mtrudel/websock/actions)
[![Docs](https://img.shields.io/badge/api-docs-green.svg?style=flat)](https://hexdocs.pm/websock)
[![Hex.pm](https://img.shields.io/hexpm/v/websock.svg?style=flat&color=blue)](https://hex.pm/packages/websock)


WebSock is a specification for apps to service WebSocket connections; you can think
of it as 'Plug for WebSockets'. Web servers such as
[Bandit](https://github.com/mtrudel/bandit/) or
[Cowboy](https://github.com/ninenines/cowboy) are expected to implement support
for hosting WebSock-based applications (possibly by way of an adapter library such
as [Plug.Cowboy](https://github.com/elixir-plug/plug_cowboy/)). WebSocket-aware
applications such as Phoenix can then be hosted within a supported web server
simply by defining conformance to the `WebSock` behaviour, in the same manner as
how Plug conformance allows their HTTP aspects to be hosted within an arbitrary
web server.

The WebSock specification is just that; a specification. There is no actual *code*
in this specification as there is within the Plug specification, largely due to
the lower-level nature of WebSockets as compared to HTTP. What you *will* find
here consists of simple interface which dictates conventions about how the
lifecycle of a WebSocket connection is managed.

The `WebSock` behaviour describes the functions that an application must
implement in order to be WebSock compliant; it is the equivalent of the `Plug`
interface, but for WebSocket connections. Server implementations are expected
to manage the upgrade process to WebSocket connections themselves, based on
their specific policy and routing decisions and aided by helper functions within
the Plug API (see below for details).

## WebSocket Lifecycle

WebSocket connections go through a well defined lifecycle, which is reflected in
the shape of the `WebSock` behaviour:

* **This step is outside the scope of the WebSock API**. A client will
  attempt to Upgrade an HTTP connection to a WebSocket connection by passing
  a specific set of headers in an HTTP request. An application may choose to
  determine the feasibility of the upgrade request however it pleases.
  Most typically, an application will then signal an upgrade to be performed by
  calling the `Plug.Conn.upgrade_adapter/3` callback with parameters indicating
  an upgrade to WebSock (note that the structure of these arguments depends on the
  particular server in use; consult `Bandit` or `Plug.Cowboy` documentation for
  details)
* Assuming the application accepted the WebSocket connection, the underlying
  server will then upgrade the HTTP connection to a WebSocket connection, and
  will call `c:WebSock.init/1` to allow the application to perform any necessary
  tasks now that the WebSocket connection is live
* The `WebSock` implementation will be notified of client data by way of the
  `c:WebSock.handle_in/2` callback
* The `WebSock` implementation may choose to be notified of control frames by way of the
  optional `c:WebSock.handle_control/2` callback. Note that user implementations DO
  NOT need to concern themselves with issuing pong frames in response to ping
  requests; the underlying server implementation MUST handle this
* The `WebSock` implementation will be notified of any messages sent to it by
  other processes by way of the `c:WebSock.handle_info/2` callback
* The `WebSock` implementation can send data to the client by returning
  a `{:push,...}` tuple from any of the above `handle_*` callback
* At any time, `c:WebSock.terminate/2` may be called to indicate a close, error or
  timeout condition 

For more information, consult the [docs](https://hexdocs.pm/websock).

## Installation

The websock package can be installed by adding `websock` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:websock, "~> 0.3.1"}
  ]
end
```

Documentation can be found at <https://hexdocs.pm/websock>.

## License

MIT
