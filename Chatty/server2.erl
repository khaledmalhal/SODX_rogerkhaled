-module(server2).
%% Exported Functions
-export([start/0, start/1]).

%% API Functions
start() ->
    ServerPid = spawn(fun() -> init_server() end),
    register(myserver, ServerPid).

start(BootServer) ->
    ServerPid = spawn(fun() -> init_server(BootServer) end),
    register(myserver, ServerPid).

init_server() ->
    process_requests([], [self()]).

init_server(BootServer) ->
    BootServer ! {server_join_req, self()},
    process_requests([], []).

process_requests(Clients, Servers) ->
    receive
        %% Messages between client and server
        {client_join_req, Name, From} ->
            NewClients = [From|Clients],  %% DONE
            broadcast(NewClients, {join, Name}),  %% DONE
            process_requests(NewClients, Servers);  %% DONE
        {client_leave_req, Name, From} ->
            NewClients = lists:delete(From, Clients),  %% DONE
            broadcast(Clients, {leave, Name}),  %% DONE
            From ! exit,
            process_requests(NewClients, Servers);  %% DONE
        {send, Name, Text} ->
            broadcast(Servers, {message, Name, Text}),  %% DONE
            process_requests(Clients, Servers);
        
        %% Messages between servers
        disconnect ->
            NewServers = lists:delete(self(), Servers),  %% DONE
            broadcast(NewServers, {update_servers, NewServers}),  %% DONE
            unregister(myserver);
        {server_join_req, From} ->
            NewServers = [From|Servers],  %% DONE
            broadcast(NewServers, {update_servers, NewServers}),  %% DONE
            process_requests(Clients, NewServers);  %% DONE
        {update_servers, NewServers} ->
            io:format("[SERVER UPDATE] ~w~n", [NewServers]),
            process_requests(Clients, NewServers);  %% DONE
            
        RelayMessage -> %% Whatever other message is relayed to its clients
            broadcast(Clients, RelayMessage),
            process_requests(Clients, Servers)
    end.

%% Local Functions
broadcast(PeerList, Message) ->
    Fun = fun(Peer) -> Peer ! Message end,
    lists:map(Fun, PeerList).
