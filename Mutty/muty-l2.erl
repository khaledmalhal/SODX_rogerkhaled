-module(muty_l2).
-export([start/3, stop/0]).

start(Lock, Sleep, Work) ->
    register(l2, Lock:start(2)),
    register(w2, worker:start("Ringo", l2, Sleep, Work)),
    ok.

stop() ->
    w2 ! stop.
