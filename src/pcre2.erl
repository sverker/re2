-module(pcre2).

-export([ compile/1
        , compile/2
        , match/2
        , match/3
        , run/2
        , run/3
        , replace/3
        , replace/4
        ]).

%% Development test functions.
-ifdef(DEV).
-export([l/1]).
-endif.

-export_type([ compile_option/0
             , match_option/0
             , replace_option/0
             ]).

-on_load(load_nif/0).

-define(nif_stub, nif_stub_error(?LINE)).
nif_stub_error(Line) ->
    erlang:nif_error({nif_not_loaded,module,?MODULE,line,Line}).

load_nif() ->
    PrivDir = case code:priv_dir(?MODULE) of
                  {error, bad_name} ->
                      EbinDir = filename:dirname(code:which(?MODULE)),
                      AppPath = filename:dirname(EbinDir),
                      filename:join(AppPath, "priv");
                  Path ->
                      Path
              end,
    erlang:load_nif(filename:join(PrivDir, "pcre2_nif"), 0).

%% NOTE: compiled_regex/0 is not declared as -opaque because:
%% 1. If you declare :: any() as an opaque type, then the compiler will
%%    complain that it's underspecified like this:
%%    Warning: opaque type compiled_regex() is underspecified and
%%    therefore meaningless
%% 2. Opaque types only make sense when exported, and the compiler will
%%    rightly complain about that as follows:
%%    Warning: opaque type compiled_regex() is not exported

-type plain_regex() :: iodata().
-type compiled_regex() :: any().
%% compiled_regex/0 is an opaque datatype containing a compiled regex created
%% by enif_make_resource(). Resources are totally opaque, which means the
%% actual type is undefined and you can make no assumption to pattern match
%% the compiled regex.
-type subject() :: iodata().
-type regex() :: plain_regex() | compiled_regex().
-type replacement() :: iodata().

-type match_option() :: 'caseless' | {'offset', non_neg_integer()}
                      | {'capture', value_spec()}
                      | {'capture', value_spec(), value_spec_type()}.
-type value_spec() :: 'all' | 'all_but_first' | 'first' | 'none'
                    | [value_id()].
-type value_spec_type() :: 'index' | 'binary'.
-type value_id() :: non_neg_integer() | string() | atom().
-type match_result() :: 'match' | 'nomatch' | {'match', list()}
                      | {'error', atom()}.

-type compile_error_str() :: string().
-type compile_error_arg() :: string().
-type compile_error() :: {'error', atom()}
                       | {atom(), compile_error_str(), compile_error_arg()}.
-type compile_option() :: 'caseless' | {'max_mem', non_neg_integer()}.
-type compile_result() :: {'ok', compiled_regex()} | compile_error().

-type replace_option() :: 'global'.
-type replace_result() :: binary() | {'error', atom()} | 'error'.

%% @doc Same as calling ``compile(Regex, [])''.
-spec compile(Regex::plain_regex()) -> compile_result().
compile(_) ->
    ?nif_stub.

%% @doc Compile regex for reuse.
%% ```
%% 1> {ok, RE} = re2:compile("Foo.*Bar", [caseless]).
%% {ok,#Ref<0.3540238268.2241986568.233969>}
%% 2> re2:match("Foo-baz-bAr", RE).
%% {match,[<<"Foo-baz-bAr">>]}'''
-spec compile(Regex::plain_regex(),
              Options::[compile_option()]) -> compile_result().
compile(_,_) ->
    ?nif_stub.

%% @doc Same as calling ``match(Subject, Regex, [])''.
-spec match(Subject::subject(), Regex::regex()) -> match_result().
match(_,_) ->
    ?nif_stub.

%% @doc Execute regular expression matching on subject string.
%% ```
%% 1> re2:match("Bar-foo-Baz", "FoO", [caseless]).
%% {match,[<<"foo">>]}'''
-spec match(Subject::subject(), Regex::regex(),
            Options::[match_option()]) -> match_result().
match(_,_,_) ->
    ?nif_stub.

%% @doc Alias for ``match/2''.
-spec run(Subject::subject(), Regex::regex()) -> match_result().
run(Subj, RE) ->
    run(Subj, RE, []).

%% @doc Alias for ``match/3''.
-spec run(Subject::subject(), Regex::regex(),
          Options::[match_option()]) -> match_result().
run(Subj, RE, Opts0) ->
    case lists:member(global, Opts0) of
	false ->
	    match(Subj, RE, Opts0);
	true ->
	    Opts1 = lists:delete(global, Opts0),
	    case lists:keytake(offset, 1, Opts1) of
		false ->
		    run_global(Subj, RE, Opts1, 0, []);
		{value, {offset, Offset}, Opts2} ->
		    run_global(Subj, RE, Opts2, Offset, [])
	    end
    end.

run_global(Subj, RE, Opts, Offset, Acc) ->
    io:format("run_global(~p, RE, ~p, ~p, ~p)\n", [Subj,Opts,Offset,Acc]),
    receive after 10 -> ok end,
    case match(Subj, RE, [{offset,Offset} | Opts]) of
	{match, [{Start,Size}|_]=Captured} ->
	    NextOffset = case Start+Size of
			     Offset ->
				 Offset+1;
			     _ ->
				 Start+Size
			 end,
	    run_global(Subj, RE, Opts, NextOffset, [Captured|Acc]);
	nomatch ->
	    case Acc of
		[] ->
		    nomatch;
		_ ->
		    {match, lists:reverse(Acc)}
	    end;
	{error, _}=Error ->
	    Error
    end.


%% @doc Same as calling ``replace(Subject, Regex, Replacement, [])''.
-spec replace(Subject::subject(), Regex::regex(),
              Replacement::replacement()) -> replace_result().
replace(_,_,_) ->
    ?nif_stub.

%% @doc Replace the matched part of the subject string with Replacement.
%% ```
%% 1> re2:replace("Baz-foo-Bar", "foo", "FoO", []).
%% <<"Baz-FoO-Bar">>'''
-spec replace(Subject::subject(), Regex::regex(), Replacement::replacement(),
              Options::[replace_option()]) -> replace_result().
replace(_,_,_,_) ->
    ?nif_stub.


%% Development test functions.
%% @private
-ifdef(DEV).
l(0) ->
    ok;
l(N) ->
    {match, [<<"o">>]} = re2:match("foo", "o", [{capture, first, binary}]),
    <<"f1o">> = re2:replace("foo", "o", "1"),
    l(N-1).
-endif.
