-module(groupy2).
-export([start/2, start/3, start/4, stop/0]).
% We use the name of the module (i.e. gms3) as the parameter Module to the start procedure. Sleep stands for up to how many milliseconds the workers should wait until the next message is sent.

process_requests(Names, Count, Module, Sleep) ->
    io:format("Names: ~w~nCount: ~w~n", [Names, Count]),
    receive
        {main_start, Name, Peer} ->
            Pid = worker:start(Name, Module, Peer, Sleep),
            Atom = list_to_atom(string:lowercase(Name)),
            io:format("Registering ~w, ~w~n", [Atom, Pid]),
            register(Atom, Pid),
            NewNames = [Atom|Names],
            process_requests(NewNames, Count + 1, Module, Sleep);
        main_stop ->
            stop(Names, Count)
    end.

start(Name, Peer) ->
    %% Start function for the Peers in the same terminal.
    Pid = whereis(requests),
    Pid ! {main_start, Name, Peer}.

start(Name, Module, Sleep) ->
    %% Start function for the Leader specifically (or the first iteration).
    Pid = worker:start(Name, Module, Sleep),
    Atom = list_to_atom(string:lowercase(Name)),
    io:format("Registering ~w, ~w~n", [Atom, Pid]),
    register(requests, spawn(fun() -> process_requests([Atom], 1, Module, Sleep) end)).

start(Name, Module, Sleep, Peer) ->
    %% Start function for the first iteration in a new terminal.
    Pid = worker:start(Name, Module, Peer, Sleep),
    Atom = list_to_atom(string:lowercase(Name)),
    io:format("Registering ~w, ~w~n", [Atom, Pid]),
    register(Atom, Pid),
    register(requests, spawn(fun() -> process_requests([Atom], 1, Module, Sleep) end)).

stop() ->
    Pid = whereis(requests),
    Pid ! main_stop.

stop(Names, Count) ->
    if
        Count > 0 ->
            Name = lists:nth(Count, Names),
            case whereis(Name) of
                undefined ->
                    ok;
                Pid ->
                    Pid ! stop
            end,
            stop(Names, Count - 1);
        true ->
            ok
    end.
