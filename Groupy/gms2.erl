-module(gms1).
-export([start/1, start/2]).
-define(timeout, 1000).

start(Name) ->
    Self = self(),
    spawn_link(fun()-> init(Name, Self) end).

init(Name, Master) ->
    leader(Name, Master, []).

start(Name, Grp) ->
    Self = self(),
    spawn_link(fun()-> init(Name, Grp, Self) end).

init(Name, Grp, Master) ->
    Self = self(),
    Grp ! {join, Self},
    receive
        {view, Leader, Slaves} ->
            MonitorRef = erlang:monitor(process, Leader),
            Master ! joined,
            slave(Name, Master, Leader, Slaves, MonitorRef)
    after ?timeout ->
        Master ! {error, "no reply from leader"}
    end.

election(Name, Master, Slaves) ->
    Self = self(),
    case Slaves of
        [Self|Rest] ->
            %% TODO: ADD SOME CODE
            leader(Name, Master, Rest);
        [NewLeader|Rest] ->
            %% TODO: ADD SOME CODE
            slave(Name, Master, NewLeader, Rest, 0)
    end.

leader(Name, Master, Slaves) ->
    receive
        {mcast, Msg} ->
            bcast(Name, {msg, Msg}, Slaves),
            Master ! {deliver, Msg},
            leader(Name, Master, Slaves);
        {join, Peer} ->
            NewSlaves = lists:append(Slaves, [Peer]),
            io:format("Leader (~w): Peer wants to join (~w) ~n", [self(), Peer]),
            bcast(Name, {view, self(), NewSlaves}, NewSlaves),
            leader(Name, Master, NewSlaves);
        stop ->
            ok;
        Error ->
            io:format("leader ~s: strange message ~w~n", [Name, Error])
    end.

bcast(_, Msg, Nodes) ->
    lists:foreach(fun(Node) -> Node ! Msg end, Nodes).

slave(Name, Master, Leader, Slaves, MonitorRef) ->
    receive
        {mcast, Msg} ->
            Leader ! {mcast, Msg},
            slave(Name, Master, Leader, Slaves, MonitorRef);
        {join, Peer} ->
            Leader ! {join, Peer},
            io:format("Slave (~w): Peer (~w) wants to join ~n", [self(), Peer]),
            slave(Name, Master, Leader, Slaves, MonitorRef);
        {msg, Msg} ->
            Master ! {deliver, Msg},
            slave(Name, Master, Leader, Slaves, MonitorRef);
        {view, NewLeader, NewSlaves} ->
            erlang:demonitor(MonitorRef, [flush]),
            NewRef = erlang:monitor(process, NewLeader),
            slave(Name, Master, NewLeader, NewSlaves, NewRef);
        {'DOWN', _Ref, process, Leader, _Reason} ->
            election(Name, Master, Slaves);
        stop ->
            ok;
        Error ->
            io:format("slave ~s: strange message ~w~n", [Name, Error])
    end.