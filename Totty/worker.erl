-module(worker).
-export([start/6]).

-define(change, 20).

start(Name, Grp, Module, Id, Sleep, Jitter) ->
    spawn(fun() -> init(Name, Grp, Module, Id, Sleep, Jitter) end).

init(Name, Grp, Module, Id, Sleep, Jitter) ->
    {A1,A2,A3} = now(),
    random:seed(A1, A2, A3),
    Gui = gui:start(Name),
    Cast = apply(Module, start, [Id, self(), Jitter]),
    Grp ! {join, self(), Cast},
    receive
        {state, Color, Peers} ->
            Cast ! {peers, Peers},
            Gui ! {color, Color},
            cast_change(Id, Cast, Sleep),
            worker(Id, Cast, Color, Gui, Sleep),
            Cast ! stop,
            Gui ! stop
    end.
    
worker(Id, Cast, Color, Gui, Sleep) ->
    receive
        {deliver, {From, N}} ->
            Color2 = change_color(N, Color),
            Gui ! {color, Color2},
            if
                From == Id ->
                    cast_change(Id, Cast, Sleep);
                true ->
                    ok
            end,
            worker(Id, Cast, Color2, Gui, Sleep);
        stop ->
            ok;
        Error ->
            io:format("strange message: ~w~n", [Error]),
            worker(Id, Cast, Color, Gui, Sleep)
    end.

change_color(N, {R,G,B}) ->
    {G, B, ((R+N) rem 256)}.
    
cast_change(Id, Cast, Sleep) ->
    Msg = {Id, random:uniform(?change)},
    timer:send_after(Sleep, Cast, {send, Msg}).