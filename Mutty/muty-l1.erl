-module(muty_l1).
-export([start/3, stop/0]).

start(Lock, Sleep, Work) ->
    register(l1, Lock:start(1)),
    register(w1, worker:start("John", l1, Sleep, Work)),
    ok.

stop() ->
    w1 ! stop.

