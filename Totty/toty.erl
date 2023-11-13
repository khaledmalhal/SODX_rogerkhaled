-module(toty).
-export([start/3, stop/0]).

start(Module, Sleep, Jitter) ->
    register(toty, spawn(fun() -> init(Module, Sleep, Jitter) end)).

stop() ->
    toty ! stop.

init(Module, Sleep, Jitter) ->
    Ctrl = self(),
    worker:start("P1", Ctrl, Module, 1, Sleep, Jitter),
    worker:start("P2", Ctrl, Module, 2, Sleep, Jitter),
    worker:start("P3", Ctrl, Module, 3, Sleep, Jitter),
    worker:start("P4", Ctrl, Module, 4, Sleep, Jitter),
    collect(4, [], []).

collect(N, Workers, Peers) ->
    if
        N == 0 ->
            Color = {0,0,0},
            lists:foreach(fun(W) -> 
                              W ! {state, Color, Peers} 
                          end, 
                          Workers),
            run(Workers);
        true ->
            receive
                {join, W, P} ->
                    collect(N-1, [W|Workers], [P|Peers])
            end
    end.

run(Workers) ->
    receive
        stop ->
            lists:foreach(fun(W) -> 
                              W ! stop 
                          end, 
                          Workers)
    end.