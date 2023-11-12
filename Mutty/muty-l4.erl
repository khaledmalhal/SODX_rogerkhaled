-module(muty_l4).
-export([start/3, stop/0]).

start(Lock, Sleep, Work) ->
    register(l4, Lock:start(4)),
    register(w4, worker:start("George", l4, Sleep, Work)),
    ok.

stop() ->
    w4 ! stop.
