-module(gms2).
-export([start/1, start/2]).
-define(timeout, 1000).
-define(arghh, 100).

start(Name) ->
    Self = self(),
    spawn_link(fun()-> init(Name, Self) end).

init(Name, Master) ->
    {A1,A2,A3} = erlang:timestamp(),
    random:seed(A1, A2, A3),
    leader(Name, Master, []).

start(Name, Grp) ->
    Self = self(),
    spawn_link(fun()-> init(Name, Grp, Self) end).

init(Name, Grp, Master) ->
    {A1,A2,A3} = erlang:timestamp(),
    random:seed(A1, A2, A3),
    Self = self(),
    Grp ! {join, Self},
    receive
        {view, Leader, Slaves} ->
            io:format("[~s] Init. Monitoring the Leader: ~w~n", [Name, Leader]),
            MonitorRef = erlang:monitor(process, Leader),
            Master ! joined,
            slave(Name, Master, Leader, Slaves, MonitorRef)
    after ?timeout ->
        Master ! {error, "no reply from leader"}
    end.

election(Name, Master, Slaves, MonitorRef) ->
    Self = self(),
    case Slaves of
        [Self|Rest] ->
            io:format("[~s] I am the new Leader. Pid: ~w~n", [Name, Self]),
            bcast(Name, {view, Self, Rest}, Rest),
            leader(Name, Master, Rest);
        [NewLeader|Rest] ->
            io:format("[~s] ~w is the new Leader~n", [Name, NewLeader]),
            slave(Name, Master, NewLeader, Rest, MonitorRef)
    end.

leader(Name, Master, Slaves) ->
    receive
        {mcast, Msg} ->
            bcast(Name, {msg, Msg}, Slaves),
            Master ! {deliver, Msg},
            leader(Name, Master, Slaves);
        {join, Peer} ->
            NewSlaves = lists:append(Slaves, [Peer]),
            io:format("Leader (~s): Peer wants to join (~w) ~n", [Name, Peer]),
            bcast(Name, {view, self(), NewSlaves}, NewSlaves),
            leader(Name, Master, NewSlaves);
        stop ->
            ok;
        Error ->
            io:format("leader ~s: strange message ~w~n", [Name, Error])
    end.

bcast(Name, Msg, Nodes) ->
    lists:foreach(fun(Node) -> Node ! Msg, crash(Name, Msg) end, Nodes).

crash(Name, Msg) ->
    case random:uniform(?arghh) of
        ?arghh ->
            io:format("leader ~s CRASHED: msg ~w~n", [Name, Msg]),
            exit(no_luck);
        _ ->
            ok
end.

slave(Name, Master, Leader, Slaves, MonitorRef) ->
    receive
        {mcast, Msg} ->
            Leader ! {mcast, Msg},
            slave(Name, Master, Leader, Slaves, MonitorRef);
        {join, Peer} ->
            Leader ! {join, Peer},
            io:format("Slave (~s): Peer (~w) wants to join ~n", [Name, Peer]),
            slave(Name, Master, Leader, Slaves, MonitorRef);
        {msg, Msg} ->
            Master ! {deliver, Msg},
            slave(Name, Master, Leader, Slaves, MonitorRef);
        {view, NewLeader, NewSlaves} ->
            erlang:demonitor(MonitorRef, [flush]),
            NewRef = erlang:monitor(process, NewLeader),
            io:format("[~s] Remonitoring the New Leader (~w)~n", [Name, NewLeader]),
            slave(Name, Master, NewLeader, NewSlaves, NewRef);
        {'DOWN', _Ref, process, Leader, _Reason} ->
            io:format("[~s] Our Leader, ~w, is down. Making a new election~n", [Name, Leader]),
            election(Name, Master, Slaves, MonitorRef);
        stop ->
            ok;
        Error ->
            io:format("slave ~s: strange message ~w~n", [Name, Error])
    end.