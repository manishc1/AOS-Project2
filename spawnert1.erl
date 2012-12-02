
-module(spawner).

-compile([nowarn_unused_function , nowarn_unused_vars]).

-export([start/0 , process/2 , findMax/0 , calculateMax/0 , findMin/0 , calculateMin/0 , findAvg/0 , calculateAvg/0 , updateFragment/2 , calculateUpdate/2 , retrieveFragment/1 , calculateRetrieve/1 , findMedian/0 , calculateMedian/0 , collectDeadProcesses/0]).


%% ---------- Definitions ----------

%% # of processes
-define(LIMIT , 1000).

%% # of Fragments
-define(FRAGLIMIT , trunc(?LIMIT/2)).

%% # of steps after convergence
-define(CONVLIMIT , trunc(2*(math:log(?LIMIT) / math:log(2)))).

-define(AVGACCURACY , (?LIMIT / 10)).

%% Timeout of receive 
-define(TIMEOUT , 1000).

%% Interval for each Gossip Iteration
-define(INTERVAL , 100).


%% ---------- Derive Fragment Value List and Id List ----------

getFragValueList([]) ->
	N=[],
	N;

getFragValueList([E | L]) ->
	{_ , Value} = E,
	lists:append(Value , getFragValueList(L)).

getFragIdList([]) ->
	N=[],
	N;

getFragIdList([E | L]) ->
	{Id , _} = E,
	[Id | getFragIdList(L)].


%% ---------- Selection of Neighbor ----------

selectNeighbor() ->
	MyNeighbors = get('neighborList'),
	random:seed(now()),
	Neighbor = lists:nth(random:uniform(length(MyNeighbors)) , MyNeighbors),
	IsAlive = is_process_alive(whereis(Neighbor)),
	if
		IsAlive == (false) ->
			  SelectedNeighbor = selectNeighbor();
		true ->
			  SelectedNeighbor = Neighbor
	end,
	SelectedNeighbor.


%% ---------- List of Operations in Secret ----------

getOperationList([]) ->
	L = [],
	L;

getOperationList([Secret | RemainingSecretList]) ->
	Operation = element(1 , Secret),
	[Operation | getOperationList(RemainingSecretList)].


getOperation(Operation , []) ->
	false;

getOperation(Operation , [Secret | RemainingSecretList]) ->
	SecretOperation = element(1, Secret),
	if
		SecretOperation  == (Operation) ->
			Secret;
		true ->
			getOperation(Operation , RemainingSecretList)
	end.

	
%% ---------- List of Live Secrets ----------

getLiveSecrets([]) ->
	T = [],
	T;

getLiveSecrets([Secret | RemainingSecretList]) ->
	TermCount = element(3 , Secret),
	TermLimit = ?CONVLIMIT,
	if
		TermCount < (TermLimit) ->
			L = [Secret | getLiveSecrets(RemainingSecretList)];
		true ->
			L = getLiveSecrets(RemainingSecretList)
	end,
	L.


%% ---------- Find Max of Two ----------

findMax2(X , Y) ->
	if
		X > Y ->
		        Max = X;
		true ->
			Max = Y
	end,
	Max.


findMyMax(0 , L , Max) ->
	Max;

findMyMax(N , L , Max) ->
	Nth = lists:nth(N , L),
        findMyMax(N-1 , L , findMax2(Max , Nth)).


%% ---------- Max Operation for Update ----------

doMaxUpdate() ->
	MySecret = get('secret'),
	Secret = getOperation(max , MySecret),
	if
		Secret /= (false) ->
		       {max , TotalCount , TermCount , Max} = Secret,
		       TermLimit = (?CONVLIMIT),
		       if
		       		TermCount < (TermLimit) ->
					NewTotalCount = TotalCount + 1,
					NewTermCount = TermCount + 1,
					if
						NewTermCount == (TermLimit) ->
							io:format("Max | ~p | | ~p |~n" , [get('name') , MySecret]);
						true ->
							true
					end;
				true ->
					NewTotalCount = TotalCount,
					NewTermCount = TermCount
			end,
			put(secret , [{max , NewTotalCount , NewTermCount , Max} | lists:keydelete(max , 1 , MySecret)]);
		true ->
			true
	end.
	
	%%io:format("Max | ~p | | ~p |~n",[get('name') , MySecret]).

	      
doMaxUpdate(Secret) ->

	{_ , _ , _ , HisMax} = Secret,

	Operation = element(1 , Secret),

	MySecret = get('secret'),

	case lists:member(Operation , getOperationList(MySecret)) of

	        false ->
			MyFragValueList = getFragValueList(get('fragment')),
			MyMax = findMyMax(length(MyFragValueList) , MyFragValueList , lists:nth(1 , MyFragValueList)),
 			Max = findMax2(HisMax , MyMax),
			put(secret , ([{max , 0 , 0 , Max} | MySecret]));
		true ->
			{_ , {_ , _ , _ , MyMax}} = lists:keysearch(max , 1 , MySecret),
			Max = findMax2(HisMax , MyMax),
			{_ , TotalCount , TermCount , _} = getOperation(Operation , MySecret),
			TermLimit = (?CONVLIMIT),
			if
				TermCount < (TermLimit) ->
					NewTotalCount = TotalCount + 1,
					if
						Max == (MyMax) ->
				       		        NewTermCount = TermCount + 1,
							if
								NewTermCount == (TermLimit) ->
									io:format("Max | ~p | | ~p |~n" , [get('name') , MySecret]);
								true ->
									true
							end;
						true ->
							NewTermCount = 0
					end;
				true ->
					NewTotalCount = TotalCount,
					NewTermCount = TermCount
			end,
			put(secret , [{max , NewTotalCount , NewTermCount , Max} | lists:keydelete(max , 1 , MySecret)])
	end.

	%%io:format("Max | ~p | | ~p |~n",[get('name') , MySecret]).


%% ---------- Find Min of Two ----------

findMin2(X , Y) ->
	if
		X > Y ->
		        Min = Y;
		true ->
			Min = X
	end,
	Min.


findMyMin(0 , L , Min) ->
	Min;

findMyMin(N , L , Min) ->
	Nth = lists:nth(N , L),
        findMyMin(N-1 , L , findMin2(Min , Nth)).

doMinUpdate() ->
	MySecret = get('secret'),
	Secret = getOperation(min , MySecret),
	if
		Secret /= (false) ->
		       {min , TotalCount , TermCount , Min} = Secret,
		       TermLimit = (?CONVLIMIT),
		       if
		       		TermCount < (TermLimit) ->
					NewTotalCount = TotalCount + 1,
					NewTermCount = TermCount + 1,
					if
						NewTermCount == (TermLimit) ->
							io:format("Min | ~p | | ~p |~n" , [get('name') , MySecret]);
						true ->
							true
					end;
			true ->
				NewTotalCount = TotalCount,
				NewTermCount = TermCount
			end,
			put(secret , [{min , NewTotalCount , NewTermCount , Min} | lists:keydelete(min , 1 , MySecret)]);
		true ->
			true
	end.


doMinUpdate(Secret) ->

	{_ , _ , _ , HisMin} = Secret,

	Operation = element(1 , Secret),

	MySecret = get('secret'),

	case lists:member(Operation , getOperationList(MySecret)) of

	        false ->
			MyFragValueList = getFragValueList(get('fragment')),
			MyMin = findMyMin(length(MyFragValueList) , MyFragValueList , lists:nth(1 , MyFragValueList)),
			Min = findMin2(HisMin , MyMin),
			put(secret , ([{min , 0 , 0 , Min} | MySecret]));
		true ->
			{_ , {_ , _ , _ , MyMin}} = lists:keysearch(min , 1 , MySecret),
			Min = findMin2(HisMin , MyMin),
			{_ , TotalCount , TermCount , _} = getOperation(Operation , MySecret),
			TermLimit = (?CONVLIMIT),
			if
				TermCount < (TermLimit) ->
					NewTotalCount = TotalCount + 1,
					if
						Min == (MyMin) ->
				       		        NewTermCount = TermCount + 1,
							if
								NewTermCount == (TermLimit) ->
									io:format("Min | ~p | | ~p |~n" , [get('name') , MySecret]);
								true ->
									true
							end;
						true ->
							NewTermCount = 0
					end;
				true ->
					NewTotalCount = TotalCount,
					NewTermCount = TermCount
			end,
			put(secret , [{min , NewTotalCount , NewTermCount , Min} | lists:keydelete(min , 1 , MySecret)])
	end.

	%%io:format("Min | ~p | | ~p |~n",[get('name') , MySecret]).


%% ---------- Find Avg of Two ----------

findAvg2(X , Xlen , Y , Ylen) ->
	((X * Xlen) + (Y * Ylen)) / (Xlen + Ylen).


isNegligibleChange(Avg , MyAvg) ->
	Diff = abs(Avg - MyAvg),
	AvgAccuracy = (?AVGACCURACY),
	if
		Diff < (AvgAccuracy) ->
		       	true;
		true ->
			false
	end.


doAvgUpdate() ->
	MySecret = get('secret'),
	Secret = getOperation(avg , MySecret),
	if
		Secret /= (false) ->
		       {avg , TotalCount , TermCount , Avg , Len} = Secret,
		       TermLimit = (?CONVLIMIT),
		       if
		       		TermCount < (TermLimit) ->
					NewTotalCount = TotalCount + 1,
					NewTermCount = TermCount + 1,
					if
						NewTermCount == (TermLimit) ->
							io:format("Avg | ~p | | ~p |~n" , [get('name') , MySecret]);
						true ->
							true
					end;
				true ->
					NewTotalCount = TotalCount,
					NewTermCount = TermCount
			end,
			put(secret , [{avg , NewTotalCount , NewTermCount , Avg , Len} | lists:keydelete(avg , 1 , MySecret)]);
		true ->
			true
	end.

doAvgUpdate(Secret) ->

	{_ , _ , _ , HisAvg , HisLen} = Secret,

	Operation = element(1 , Secret),

	MySecret = get('secret'),

	case lists:member(Operation , getOperationList(MySecret)) of

	        false ->
			MyFragValueList = getFragValueList(get('fragment')),
			MyAvg = (lists:foldl(fun(X, Sum) -> X + Sum end, 0, MyFragValueList)) / length(MyFragValueList),
			MyLen = length(MyFragValueList),
			Avg = findAvg2(HisAvg , HisLen , MyAvg , MyLen),
			put(secret , ([{avg , 0 , 0 , Avg , MyLen} | MySecret]));
		true ->
			{_ , {_ , _ , _ , MyAvg , MyLen}} = lists:keysearch(avg , 1 , MySecret),
			Avg = findAvg2(HisAvg , HisLen , MyAvg , MyLen),
			{_ , TotalCount , TermCount , _ , _} = getOperation(Operation , MySecret),
			TermLimit = (?CONVLIMIT),
			if
				TermCount < (TermLimit) ->
					  NewTotalCount = TotalCount + 1,
					  IsNegligibleChange = isNegligibleChange(Avg , MyAvg),
					  if
						IsNegligibleChange == (true) ->
				       		        NewTermCount = TermCount + 1,
							if
								NewTermCount == (TermLimit) ->
									io:format("Avg | ~p | | ~p |~n" , [get('name') , MySecret]);
								true ->
									true
							end;
						true ->
							NewTermCount = 0
					end;
				true ->
					NewTotalCount = TotalCount,
					NewTermCount = TermCount
			end,
			put(secret , [{avg , NewTotalCount , NewTermCount , Avg , MyLen} | lists:keydelete(avg , 1 , MySecret)])
	end.
	%%io:format("Avg | ~p | | ~p , ~p |~n",[get('name') , Avg , MyLen]).


%% ---------- Fragment Update ----------

doUpdateFragUpdate() ->
	MySecret = get('secret'),
	Secret = getOperation(update_frag , MySecret),
	if
		Secret /= (false) ->
		       {_ , TotalCount , TermCount , Id , Value} = Secret,
		       TermLimit = (?CONVLIMIT),
		       if
				TermCount < (TermLimit) ->
					NewTotalCount = TotalCount + 1,
					NewTermCount = TermCount + 1,
					if
						NewTermCount == (TermLimit) ->
							io:format("UpF | ~p | | ~p | | ~p |~n" , [get('name') , MySecret , get('fragment')]);
						true ->
							true
					end;
				true ->
					NewTotalCount = TotalCount,
					NewTermCount = TermCount
			end,
			put(secret , [{update_frag , NewTotalCount , NewTermCount , Id , Value} | lists:keydelete(update_frag , 1 , MySecret)]);
		true ->
			true
	end.


doUpdateFragUpdate(Secret) ->

	Operation = element(1, Secret),

	MySecret = get('secret'),

        case lists:member(Operation , getOperationList(MySecret)) of

	        false ->
			{_ , _ , _ , HisId , HisValue} = Secret,
			MyFragIdList = getFragIdList(get('fragment')),
			IsPresent = lists:member(HisId , MyFragIdList),			
	 		if
			        IsPresent == (true) ->
					NewFragment = [{HisId , HisValue} | lists:keydelete(HisId , 1 , get('fragment'))],
					put(fragment , (NewFragment));
				true ->
		      		     io:format("")
	 		end,
			NewSecret = {update_frag , 0 , 0 , HisId , HisValue},
			put(secret , ([Secret | MySecret]));
		true ->
			{_ , {_ , TotalCount , TermCount , Id , Value}} = lists:keysearch(update_frag , 1 , MySecret),
			TermLimit = (?CONVLIMIT),
			if
				TermCount < (TermLimit) ->
					NewTotalCount = TotalCount + 1,
					if
						length(Value) /= 0 ->
				       		        NewTermCount = TermCount + 1,
							if
								NewTermCount == (TermLimit) ->
									io:format("UpF | ~p | | ~p | | ~p |~n" , [get('name') , MySecret , get('fragment')]);
								true ->
									true
							end;
						true ->
							NewTermCount = 0
					end;
				true ->
					NewTotalCount = TotalCount,
					NewTermCount = TermCount
			end,
			put(secret , [{update_frag , NewTotalCount , NewTermCount , Id , Value} | lists:keydelete(update_frag , 1 , MySecret)]),
			io:format("")
	end.
	%%io:format("UpF | ~p | | ~p |~n", [get('name') , get('fragment')]).


%% ---------- Fragment Retrieval ----------

doRetrieveFragUpdate() ->

	MySecret = get('secret'),
	Secret = getOperation(retrieve_frag , MySecret),
	if
		Secret /= (false) ->
		       {retrieve_frag , TotalCount , TermCount , FragId , FragValue} = Secret,
		       TermLimit = (?CONVLIMIT),
		       if
		       		TermCount < (TermLimit) ->
					NewTotalCount = TotalCount + 1,
					NewTermCount = TermCount + 1,
					if
						NewTermCount == (TermLimit) ->
							io:format("Ref | ~p | | ~p |~n" , [get('name') , MySecret]);
						true ->
							true
					end;
				true ->
					NewTotalCount = TotalCount,
					NewTermCount = TermCount
			end,
			put(secret , [{retrieve_frag , NewTotalCount , NewTermCount , FragId , FragValue} | lists:keydelete(retrieve_frag , 1 , MySecret)]);
		true ->
			true
	end.
	%%io:format("Ref | ~p | | ~p |~n" , [get('name') , MySecret]).


doRetrieveFragUpdate(Secret) ->

	{_ , _ , _ , HisFragId , HisFragValue} = Secret,

	MyFragIdList = getFragIdList(get('fragment')),

	IdPresent = lists:member(HisFragId , MyFragIdList),

	IsPresent = getMatch(Secret , get('secret')),
%%io:format("| ~p | | ~p | | ~p |~n",[get('name') , IdPresent , IsPresent]),
	case  IsPresent of

	        false ->
			if
				IdPresent == (true) ->
					{_ , {_ , MyFragValue}} = lists:keysearch(HisFragId , 1 , get('fragment')),
					put(secret , ([{retrieve_frag , 0 , 0 , HisFragId , MyFragValue} | get('secret')]));
				true ->
					put(secret , ([{retrieve_frag , 0 , 0 , HisFragId , HisFragValue} | get('secret')]))
			end;
		_ ->
			if
				IdPresent == (true) ->
					{_ , {_ , MyFragValue}} = lists:keysearch(HisFragId , 1 , get('fragment')),
					%%put(secret , ([{retrieve_frag , HisFragId , MyFragValue} | lists:filter(fun(X) -> X /= (IsPresent) end, get('secret'))])),
					FragValue = MyFragValue;
				true ->
				        if
						length(HisFragValue) /=0 ->
							%%put(secret , ([Secret | lists:filter(fun(X) -> X /= (IsPresent) end, get('secret'))])),
							FragValue = HisFragValue;
					true ->
						{_ , _ , _ , _ , MyFragValue} = IsPresent,
						FragValue = MyFragValue
					end
			end,
			{_ , TotalCount , TermCount , _ , PrevFragValue} = IsPresent,
			TermLimit = (?CONVLIMIT),
			if
				TermCount < (TermLimit) ->
					NewTotalCount = TotalCount + 1,
					if
						FragValue == (PrevFragValue) ->
				       		        NewTermCount = TermCount + 1,
							if
								NewTermCount == (TermLimit) ->
									io:format("ReF | ~p | | ~p |~n" , [get('name') , get('secret')]);
								true ->
									true
							end;
						true ->
							NewTermCount = 0
					end;
				true ->
					NewTotalCount = TotalCount,
					NewTermCount = TermCount
			end,
			put(secret , ([{retrieve_frag , NewTotalCount , NewTermCount , HisFragId , FragValue} | lists:filter(fun(X) -> X /= (IsPresent) end, get('secret'))]))
	end.
	%%io:format("ReF | ~p | | ~p |~n" , [get('name') , get('secret')]).


%% ---------- Find Median ----------

findMedian(List) ->

	SortedList = lists:sort(List),

	Length = length(SortedList),

	case (Length rem 2) of

	        0 ->
		        Med1 = trunc(Length / 2),
			Med2 = Med1 + 1,
			Median = (lists:nth(Med1 , SortedList) + lists:nth(Med2 , SortedList)) / 2;
		1 ->
			Med = trunc((Length + 1) / 2),
			Median = lists:nth(Med , SortedList)
	end,

	Median.


mergeFragLists(L , []) ->
	L;

mergeFragLists(L1 , [E | L2]) ->
	case lists:member(E , L1) of
	        false ->
		        L3 = [E | L1];
		true ->
			L3 = L1
	end,
	mergeFragLists(L3 , L2).


getValueList([] , ValueList) ->
	ValueList;
getValueList([E | L] , ValueList) ->
	{_ , Value} = E,
	NewValueList = lists:append(Value , ValueList),
	getValueList(L , NewValueList).


doMedianUpdate(Secret) ->

	{_ , _ , HisFragList} = Secret,

	Operation = element(1 , Secret),

	case lists:member(Operation , getOperationList(get('secret'))) of

	        false ->
			MyFragments = get('fragment'),
			MergedList = mergeFragLists(MyFragments , HisFragList),
			MergedValueList = getValueList(MergedList , []),
			MyMedian = findMedian(MergedValueList),
			put(secret , ([{median , MyMedian , MergedList} | get('secret')]));
		true ->
			{_ , {_ , _ , MyFragList}} = lists:keysearch(median , 1 , get('secret')),
			MergedList = mergeFragLists(MyFragList , HisFragList),
			MergedValueList = getValueList(MergedList , []),
			MyMedian = findMedian(MergedValueList),
			put(secret , [{median , MyMedian , MergedList} | lists:keydelete(median , 1 , get('secret'))])
	end,

	io:format("Median | ~p | | ~p |~n",[get('name') , MyMedian]).


%% ---------- Update Driver ----------

update() ->
	doMaxUpdate(),
	doMinUpdate(),
	doAvgUpdate(),
	doUpdateFragUpdate(),
	doRetrieveFragUpdate().

update([]) ->
	true;

update([Secret | RemainingSecret]) ->
	
        Operation = element(1,Secret),

	case Operation of
	        max ->
		        doMaxUpdate(Secret);
		min ->
		        doMinUpdate(Secret);
		avg ->
		        doAvgUpdate(Secret);
		update_frag ->
		        doUpdateFragUpdate(Secret);
		retrieve_frag ->
		        doRetrieveFragUpdate(Secret);
		median ->
		        doMedianUpdate(Secret);
		_ ->
		        io:format("")
	end,
		
	update(RemainingSecret).

		
%% ---------- Push ----------

waitPushResponse() ->
	receive

		{push_response , NeighborSecret} ->
			%%io:format("| ~p | going to update", [get('name')]),
			if
				length(NeighborSecret) /=0 ->
		        		update(NeighborSecret);
				true ->
					update(),
					io:format("")
			end

	after ?TIMEOUT ->
	      	io:format("")
	end.


push() ->
	Neighbor = selectNeighbor(),
	Name = get('name'),
	if
		Name /= Neighbor ->
			Secret = getLiveSecrets(get('secret')),
			if
				length(Secret) /= 0 ->
					%%io:format("| ~p | doing push~n| ~p |~n| ~p |~n~n~n" , [get('name') , get('secret') , Secret]),
					Neighbor ! {push_request , Secret , Name},
					waitPushResponse();
				true ->
					io:format("")
			end;
		true ->
			io:format("")
	end,
	io:format("").


%% ---------- Pull ----------

waitPullComplete() ->
	receive

		{pull_complete , NeighborSecret} ->
			%%io:format("| ~p | going to update", [get('name')]),
			if
				length(NeighborSecret) /=0 ->
		        		update(NeighborSecret);
				true ->
					update(),
					io:format("")
			end

	after ?TIMEOUT ->
	      	io:format("")

	end.


waitPullResponse() ->
	receive

		{pull_response , NeighborSecret , Neighbor} ->
			build(NeighborSecret),
			Secret = getLiveSecrets(get('secret')),
			%%io:format("| ~p | sending pull_complete~n| ~p |~n| ~p |~n~n~n",[get('name'),get('secret') , Secret]),
			whereis(Neighbor) ! {pull_complete , Secret},
			%%io:format("| ~p | going to update", [get('name')]),
			if
				length(NeighborSecret) /=0 ->
		        		update(NeighborSecret);
				true ->
					update(),
					io:format("")
			end;

		 no_secret ->
			io:format("")

	after ?TIMEOUT ->
		io:format("")

	end.


pull() ->
	Neighbor = selectNeighbor(),
	Name = get('name'),
	if
		Neighbor /= Name ->
			 %%io:format("| ~p |'s Pull~n",[get('name')]),
			 whereis(Neighbor) ! {pull_request , Name},
			 waitPullResponse();
		true ->
			 io:format("")
	end,
	io:format("").


%% ---------- Push And Pull Alternation ----------

pushpull() ->
	Phase = get('phase'),
	%%io:format("| ~p | Phase | ~p |~n",[get('name'),get('phase')]),
	if
		Phase == (push) ->
		      	%%io:format("| ~p | in push~n",[get('name')]),
			Secret = getLiveSecrets(get('secret')),
			if
				length(Secret) /= (0) ->
				push();
			true ->
				io:format("")
			end,
			put(phase , (pull));
		true ->
		      	%%io:format("| ~p | in pull~n",[get('name')]),
			timer:sleep(2000),
			pull(),
			put(phase , (push))
	end,
	%%io:format("| ~p | return from pull~n",[get('name')]).
	io:format("").


%% ---------- Build The Secret To Be Returned ----------

doMaxBuild(Secret) ->

	Operation = element(1 , Secret),

	MySecret = get('secret'),

	case lists:member(Operation , getOperationList(MySecret)) of

	        false ->
			MyFragValueList = getFragValueList(get('fragment')),
			MyMax = findMyMax(length(MyFragValueList) , MyFragValueList , lists:nth(1 , MyFragValueList)),
			put(secret , ([{max , 0 , 0 , MyMax} | MySecret]));
		true ->
			true
	end.


doMinBuild(Secret) ->

	Operation = element(1 , Secret),

	MySecret = get('secret'),

	case lists:member(Operation , getOperationList(MySecret)) of

	        false ->
			MyFragValueList = getFragValueList(get('fragment')),
			MyMin = findMyMin(length(MyFragValueList) , MyFragValueList , lists:nth(1 , MyFragValueList)),
			put(secret , ([{min , 0 , 0 , MyMin} | MySecret]));
		true ->
			true
	end.


doAvgBuild(Secret) ->

	Operation = element(1 , Secret),

	MySecret = get('secret'),

	case lists:member(Operation , getOperationList(MySecret)) of

	        false ->
			MyFragValueList = getFragValueList(get('fragment')),
			MyAvg = (lists:foldl(fun(X, Sum) -> X + Sum end, 0, MyFragValueList)) / length(MyFragValueList),
			MyLen = length(MyFragValueList),
			put(secret , ([{avg , 0 , 0 , MyAvg , MyLen} | MySecret]));
		true ->
			true
	end.


getMatch(_, []) ->
        false;

getMatch(Secret , [MySecret | MyRemainingSecret]) ->

	{HisSec , _ , _ , HisFragId , _} = Secret,
	{MySec , _ , _ , MyFragId , _} = MySecret,

        case  ((HisSec == (MySec)) and (HisFragId == (MyFragId)))of
	        true ->
		        MySecret;
		false ->
		        getMatch(Secret , MyRemainingSecret)
	end.


doRetrieveFragBuild(Secret) ->

	{_ , _ , _ , HisFragId , HisFragValue} = Secret,

	MyFragIdList = getFragIdList(get('fragment')),

	IdPresent = lists:member(HisFragId , MyFragIdList),

	IsPresent = getMatch(Secret , get('secret')),
	%%io:format("| ~p | | ~p | | ~p |~n",[get('name') , IdPresent , IsPresent]),
	case  IsPresent of

	        false ->
			if
				IdPresent == (true) ->
					{_ , {_ , MyFragValue}} = lists:keysearch(HisFragId , 1 , get('fragment')),
					put(secret , ([{retrieve_frag , 0 , 0 , HisFragId , MyFragValue} | get('secret')]));
				true ->
					put(secret , ([{retrieve_frag , 0 , 0 , HisFragId , HisFragValue} | get('secret')]))
			end;
		_ ->
			if
				IdPresent == (true) ->
					{_ , {_ , MyFragValue}} = lists:keysearch(HisFragId , 1 , get('fragment')),
					%%put(secret , ([{retrieve_frag , HisFragId , MyFragValue} | lists:filter(fun(X) -> X /= (IsPresent) end, get('secret'))])),
					FragValue = MyFragValue;
				true ->
				        if
						length(HisFragValue) /=0 ->
							%%put(secret , ([Secret | lists:filter(fun(X) -> X /= (IsPresent) end, get('secret'))])),
							FragValue = HisFragValue;
					true ->
						{_ , _ , _ , _ , MyFragValue} = IsPresent,
						FragValue = MyFragValue
					end
			end,
			{_ , TotalCount , TermCount , _ , PrevFragValue} = IsPresent,
			TermLimit = (?CONVLIMIT),
			if
				TermCount < (TermLimit) ->
					NewTotalCount = TotalCount + 1,
					if
						FragValue == (PrevFragValue) ->
				       		        NewTermCount = TermCount + 1,
							if
								NewTermCount == (TermLimit) ->
									io:format("ReF | ~p | | ~p |~n" , [get('name') , get('secret')]);
								true ->
									true
							end;
						true ->
							NewTermCount = 0
					end;
				true ->
					NewTotalCount = TotalCount,
					NewTermCount = TermCount
			end,
			put(secret , ([{retrieve_frag , NewTotalCount , NewTermCount , HisFragId , FragValue} | lists:filter(fun(X) -> X /= (IsPresent) end, get('secret'))]))
	end.
	%%io:format("ReF | ~p | | ~p |~n" , [get('name') , get('secret')]).


doMedianBuild(Secret) ->

	Operation = element(1 , Secret),

	case lists:member(Operation , getOperationList(get('secret'))) of

	        false ->
			MyMedian = findMedian(getFragValueList(get('fragment'))),
			put(secret , ( [ {median , MyMedian , get('fragment')} | get('secret') ] ) );
		true ->
			true;
		_ ->
			io:format("")
	end.


build([]) ->
	true;

build([Secret | RemainingSecret]) ->

        Operation = element(1,Secret),

	%%io:format("~p ~p ~p~n",[self() , Operation , get('secret')]),

	case Operation of
	        max ->
		        doMaxBuild(Secret);
		min ->
		        doMinBuild(Secret);
		avg ->
		        doAvgBuild(Secret);
		retrieve_frag ->
			doRetrieveFragBuild(Secret);
		median ->
			doMedianBuild(Secret);
		_ ->
		        io:format("")
	end,
		
	build(RemainingSecret).


%% ---------- Listen And PushPull Alternation of Process ----------

listen() ->

	%%io:format("Secret | ~p | | ~p |~n",[get('name') , get('secret')]),
	pushpull(),

	receive

		{pull_request , Neighbor} ->
			%%io:format("| ~p | : pull request from | ~p | | ~p | ~p |~n",[get('name') , Neighbor , whereis(Neighbor) , registered()]),
			Secret = getLiveSecrets(get('secret')),
			if
				length(Secret) == (0) ->
				       	whereis(Neighbor) ! no_secret,
					io:format("");
				true ->
					%%io:format("| ~p | doing pull_response~n| ~p |~n| ~p |~n~n~n",[get('name') , get('secret') , Secret]),
					whereis(Neighbor) ! {pull_response , Secret , get('name')},
					waitPullComplete()
			end,
			listen();

		{push_request , NeighborSecret , Neighbor} ->
			build(NeighborSecret),
			Secret = getLiveSecrets(get('secret')),
			%%io:format("| ~p | doing pull_response~n| ~p |~n| ~p |~n~n~n",[get('name') , get('secret') , Secret]),
			Neighbor ! {push_response ,Secret},
			%%io:format("| ~p | going to update", [get('name')]),
			if
				length(NeighborSecret) /= 0 ->
					update(NeighborSecret);
				true ->
					update(),
					io:format("")
			end,
			listen();

		find_max ->
			MyFragValueList = getFragValueList(get('fragment')),
			NewSecret = [{max , 0 , 0 , findMyMax(length(MyFragValueList) , MyFragValueList , lists:nth(1 , MyFragValueList))} | get('secret')],
			put(secret , (NewSecret)),
			listen();

		find_min ->
			MyFragValueList = getFragValueList(get('fragment')),
			NewSecret = [{min , 0 , 0 , findMyMin(length(MyFragValueList) , MyFragValueList , lists:nth(1 , MyFragValueList))} | get('secret')],
			put(secret , (NewSecret)),
			listen();

		find_avg ->
			MyFragValueList = getFragValueList(get('fragment')),
			MyAvg = (lists:foldl(fun(X, Sum) -> X + Sum end, 0, MyFragValueList)) / length(MyFragValueList),
			MyLen = length(MyFragValueList),
			put(secret , ([{avg , 0 , 0 , MyAvg , MyLen} | get('secret')])),
			listen();

		{update_fragment , FragmentId , Value} ->
			MyFragIdList = getFragIdList(get('fragment')),
			IsPresent = lists:member(FragmentId , MyFragIdList),
			if
				IsPresent == (true) ->
					NewFragment = [{FragmentId , Value} | lists:keydelete(FragmentId , 1 , get('fragment'))],
					put(fragment , (NewFragment));
				true ->
					 io:format("")
			end,
			put(secret , ([{update_frag , 0 , 0 , FragmentId , Value} | get('secret')])),
			listen();

		{retrieve_fragment , FragmentId} ->
			MyFragIdList = getFragIdList(get('fragment')),
			IsPresent = lists:member(FragmentId , MyFragIdList),
			if
				IsPresent == (true) ->
					MyFragments = get('fragment'),
				        {_ , {MyFragId , MyFragValue}} = lists:keysearch(FragmentId , 1 , MyFragments),
					put(secret , ([{retrieve_frag , 0 , 0 , MyFragId , MyFragValue} | get('secret')]));
				true ->
					put(secret , ([{retrieve_frag , 0 , 0 , FragmentId , []} | get('secret')]))					
			end,
			listen();

		find_median ->
			NewSecret = [ {median , findMedian(getFragValueList(get('fragment'))) , get('fragment')} | get('secret')],
			put(secret , (NewSecret)),
			listen()

	after ?TIMEOUT ->
	      listen()

	end.


%% ---------- Initialize the Process Dictionary ----------

init_dict(MyNumber, NeighborList) ->

	put(number , (MyNumber)),
	put(name , (list_to_atom( string:concat("p" , integer_to_list(MyNumber))))),
	put(neighborList , (NeighborList)),
	put(secret , ([])),
	put(fragment , [{(MyNumber rem ?FRAGLIMIT) , [(MyNumber rem ?FRAGLIMIT) , ((MyNumber rem ?FRAGLIMIT) + ?FRAGLIMIT)]} , {((MyNumber rem ?FRAGLIMIT) + ?FRAGLIMIT) , [(MyNumber rem ?FRAGLIMIT) + ?LIMIT , ((MyNumber rem ?FRAGLIMIT) + ?FRAGLIMIT) + ?LIMIT]}]),
	put(phase , (push)),

	io:format("| ~p | | ~p | | ~p | | ~p | | ~p |~n",[get('number') , get('name') , get('neighborList') , get('secret') , get('fragment')]),
	io:format("").


%% ---------- Entry Point of Process ----------

process(MyNumber , NeighborList) ->

	init_dict(MyNumber , NeighborList),
	listen(),
	io:format("| ~p | I am exiting",[get('name')]).


%% ---------- Ring Topology ----------

getRingNeighborList(MyNumber) ->

	Me = list_to_atom( string:concat( "p" , integer_to_list( MyNumber ))),
	Predecessor = list_to_atom( string:concat( "p" , integer_to_list( ((?LIMIT + MyNumber - 1) rem ?LIMIT )))),
	Successor = list_to_atom( string:concat( "p" , integer_to_list( ((MyNumber + 1) rem ?LIMIT )))),

	NeighborList = [Me , Predecessor , Successor],
	NeighborList.


%% ---------- Chord Topology ----------

floor(X) ->
    T = erlang:trunc(X),
    case (X - T) of
        Neg when Neg < 0 -> T - 1;
        Pos when Pos > 0 -> T;
        _ -> T
    end.


ceiling(X) ->
        T = erlang:trunc(X),
	case (X - T) of
	        Neg when Neg < 0 -> T;
		Pos when Pos > 0 -> T + 1;
		_ -> T
	end.


log2(X) ->
	math:log(X) / math:log(2).


getList(MyNumber , List , 0) ->
	List;

getList(MyNumber , List , I) ->
	NewList = [list_to_atom( string:concat( "p" , integer_to_list( trunc((MyNumber + math:pow(2,I-1))) rem ?LIMIT ))) | List],
	getList(MyNumber , NewList , I-1).


getChordNeighborList(MyNumber) ->
	Length = ceiling(log2(?LIMIT)),

	Me = list_to_atom( string:concat( "p" , integer_to_list( MyNumber ))),
	T1 = [Me | getList(MyNumber , [] , Length)],

	Successor = list_to_atom( string:concat( "p" , integer_to_list( ((MyNumber + 1) rem ?LIMIT )))),
	IsSuccessor = lists:member(Successor , T1),
	if
		IsSuccessor == (false) ->
			T2 = [Successor | T1];
		true ->
			T2 = T1
	end,

	Predecessor = list_to_atom( string:concat( "p" , integer_to_list( ((?LIMIT + MyNumber - 1) rem ?LIMIT )))),
	IsPredecessor = lists:member(Predecessor , T2),
	if
		IsPredecessor == (false) ->
			T3 = [Predecessor | T2];
		true ->
			T3 = T2
	end,

	MirrorMyNumber = (?LIMIT - MyNumber - 1),
	MirrorMe = list_to_atom( string:concat( "p" , integer_to_list( MirrorMyNumber ))),
	IsMirrorMe = lists:member(MirrorMe , T3),
	if
		IsMirrorMe == (false) ->
			T4 = [MirrorMe | T3];
		true ->
			T4 = T3
	end,

	MirrorSuccessor = list_to_atom( string:concat( "p" , integer_to_list( ((MirrorMyNumber + 1) rem ?LIMIT )))),
	IsMirrorSuccessor = lists:member(MirrorSuccessor , T4),
	if
		IsMirrorSuccessor == (false) ->
			T5 = [MirrorSuccessor | T4];
		true ->
			T5 = T4
	end,

	MirrorPredecessor = list_to_atom( string:concat( "p" , integer_to_list( ((?LIMIT + MirrorMyNumber - 1) rem ?LIMIT )))),
	IsMirrorPredecessor = lists:member(MirrorPredecessor , T5),
	if
		IsMirrorPredecessor == (false) ->
			NeighborList = [MirrorPredecessor | T5];
		true ->
			NeighborList = T5
	end,

	NeighborList.


%% ---------- Mirror Ring Topology ----------

getMirrorRingNeighborList(MyNumber) ->

	Me = list_to_atom( string:concat( "p" , integer_to_list( MyNumber ))),
	Predecessor = list_to_atom( string:concat( "p" , integer_to_list( ((?LIMIT + MyNumber - 1) rem ?LIMIT )))),
	Successor = list_to_atom( string:concat( "p" , integer_to_list( ((MyNumber + 1) rem ?LIMIT )))),
	T1 = [Me , Predecessor , Successor],

	MirrorMyNumber = (?LIMIT - MyNumber - 1),
	MirrorMe = list_to_atom( string:concat( "p" , integer_to_list( MirrorMyNumber ))),
	IsMirrorMe = lists:member(MirrorMe , T1),
	if
		IsMirrorMe == (false) ->
			T2 = [MirrorMe | T1];
		true ->
			T2 = T1
	end,

	MirrorSuccessor = list_to_atom( string:concat( "p" , integer_to_list( ((MirrorMyNumber + 1) rem ?LIMIT )))),
	IsMirrorSuccessor = lists:member(MirrorSuccessor , T2),
	if
		IsMirrorSuccessor == (false) ->
			T3 = [MirrorSuccessor | T2];
		true ->
			T3 = T2
	end,

	MirrorPredecessor = list_to_atom( string:concat( "p" , integer_to_list( ((?LIMIT + MirrorMyNumber - 1) rem ?LIMIT )))),
	IsMirrorPredecessor = lists:member(MirrorPredecessor , T3),
	if
		IsMirrorPredecessor == (false) ->
			NeighborList = [MirrorPredecessor | T3];
		true ->
			NeighborList = T3
	end,

	NeighborList.


%% ---------- Creation of Processes ----------

do_spawn(0) ->
	ok;

do_spawn(N) ->
    	ProcessName = list_to_atom( string:concat( "p" , integer_to_list( ?LIMIT - N ) ) ),
	process_flag(trap_exit, true),
	%%register(ProcessName , spawn_link(?MODULE , process , [(?LIMIT - N) , getRingNeighborList( ?LIMIT - N )])),
	register(ProcessName , spawn_link(?MODULE , process , [(?LIMIT - N) , getChordNeighborList( ?LIMIT - N )])),
	%%register(ProcessName , spawn_link(?MODULE , process , [(?LIMIT - N) , getMirrorRingNeighborList( ?LIMIT - N )])),
	do_spawn(N-1).


%% ---------- Listsing Dead Processes ----------

checkIfDead(0 , List) ->
	List;

checkIfDead(N , List) ->
     	 ProcessName = list_to_atom( string:concat( "p" , integer_to_list( N ) ) ),
	 IsPresent = lists:member(ProcessName , registered()),
	 if
		IsPresent == (true) ->
			  NewList = checkIfDead(N-1 , List);
		true ->
			  NewList = [ProcessName | checkIfDead(N-1 , List)]
	 end,
	 NewList.


collectDeadProcesses() ->
	io:format("Dead | ~p |~n", [checkIfDead(?LIMIT-1 , [])]),
	timer:sleep(3000),
	collectDeadProcesses().


%% ---------- Entry Point ----------

start() ->
	do_spawn(?LIMIT),
	%%findMax(),
	%%findAvg(),
	%%findMin(),
	%%updateFragment(0 , [10,20]),
	%%retrieveFragment(trunc(?LIMIT/4)),
	%%retrieveFragment(1),
	%%findMedian(),
	%%register(collector , spawn(?MODULE , collectDeadProcesses , [])),
	io:format("").


%% ---------- Various Operations ----------

calculateMax() ->
	whereis(p0) ! find_max,
	exit(self() , "end of purpose").

findMax() ->
	spawn(?MODULE , calculateMax , []).


calculateMin() ->
	whereis(p0) ! find_min,
	exit(self() , "end of purpose").

findMin() ->
	spawn(?MODULE , calculateMin , []).


calculateAvg() ->
	whereis(p0) ! find_avg,
	exit(self() , "end of purpose").

findAvg() ->
	spawn(?MODULE , calculateAvg , []).


calculateUpdate(FragmentId , Value) ->
	whereis(p0) ! {update_fragment , FragmentId , Value},
	exit(self() , "end of purpose").

updateFragment(FragmentId , Value) ->
	spawn(?MODULE , calculateUpdate , [FragmentId , Value]).


calculateRetrieve(FragmentId) ->
	whereis(p0) ! {retrieve_fragment , FragmentId},
	exit(self() , "end of purpose").

retrieveFragment(FragmentId) ->
	spawn(?MODULE , calculateRetrieve , [FragmentId]).


calculateMedian() ->
	whereis(p0) ! find_median,
	exit(self() , "end of purpose").

findMedian() ->
	spawn(?MODULE , calculateMedian , []).


%% ---------- Unused Functions ----------


loop() ->
    receive

        {Exit , PID} -> 
	      {k, F} = file:open("exit.txt", [read, write]),
	      io:write({F, donnie, "Donnie Pinkston"}),
	      file:close(F),
	      io:format("@@@@@@@@@ ~p @@@@@@@@ | ~p |~n", [PID , Exit]);
	{Exit , PID , normal} -> 
	      io:format("@@@@@@@@@ ~p @@@@@@@@ | ~p |~n", [PID , Exit]),
	      {k, F} = file:open("exit.txt", [read, write]),
	      io:format("~p.~n",[{F, donnie, "Donnie Pinkston"}]),
	      file:close(F),
	      exit(normal);
        {Exit , PID , Reason} -> 
	      {k, F} = file:open("exit.txt", [read, write]),
	      io:write({F, donnie, "Donnie Pinkston"}),
	      file:close(F),
	      io:format("@@@@@@@@@ ~p @@@@@@@@ | ~p | | ~p |~n", [PID , Exit , Reason])
    end,
    loop().



%% change according to the secrets
updateMinMaxAvg(NeighborSecret) ->
	MySecret = get('secret'),
	HisSecret = lists:nth(1 , NeighborSecret),
	{_ , HisValue} = HisSecret,
	
	if
		length(MySecret) == (0) ->
			MyNumber = get('number'),
			io:format("~p",[MyNumber]);
			%%Max = findMax(HisValue,MyNumber);
			%%Avg = findAvg2(HisValue,MyNumber);
			%%Min = findMin(HisValue,MyNumber);
		true ->
			MySingleSecret = lists:nth(1 , MySecret),
			{_ , MyValue} = MySingleSecret
			%%Max = findMax(HisValue,MyValue)
			%%Avg = findAvg2(HisValue,MyValue)
			%%Min = findMin(HisValue,MyValue)
	end,

	%%MyNewSecret = [{max , Max}],
	%%MyNewSecret = [{avg , Avg}],
	%%MyNewSecret = [{min , Min}],
	Me = get('number'),
	if
		(Me rem 10) == (0) ->
		     	 %%io:format("Result | ~p | | ~p |~n",[get('name') , Max]);
		     	 %%io:format("Result | ~p | | ~p |~n",[get('name') , Avg]);
		     	 %%io:format("Result | ~p | | ~p |~n",[get('name') , Min]);
			 true;
		true ->
			 io:format("")
	end.
	%%put(secret , (MyNewSecret)).
	

updateFrag(NeighborSecret) ->
	MySecret = get('secret'),
	if
		length(NeighborSecret) /=0 ->
			HisSecret = lists:nth(1 , NeighborSecret),
			{_ , HisId , HisValue} = HisSecret,
			IsSecret = lists:member(HisSecret , MySecret),	
			if
				IsSecret == (false) ->
			 		 MyNewSecret = [HisSecret | MySecret];
				true ->
					MyNewSecret = MySecret
			end,
	 		 MyFragId = get('fragmentId'),
	 		 if
				HisId == (MyFragId) ->
      	 	      		      put(fragmentValue , (HisValue));
				true ->
		      		     io:format("")
	 		end,
			MyNumber = get('number'),
			if
				(MyNumber rem trunc(?LIMIT/4)) == (0) ->
		     			  io:format("Result | ~p | | ~p , ~p | | ~p | | ~p ~p | | ~p |~n",[get('name') , get('fragmentId') , get('fragmentValue') , get('secret') , HisId , HisValue , IsSecret]);
				true ->
				     io:format("")
			end,
			put(secret , (MyNewSecret));
		true ->
		     io:format("")
	end.


buildSecretUpdate(NeighborSecret , 0) ->
	io:format("");
buildSecretUpdate(NeighborSecret , I) ->
	Secret = lists:nth(I , NeighborSecret),
	IsSecret = lists:member(Secret , get('secret')),
	if
		IsSecret == (false) ->
			NewSecret = [{max,get('number')} | get('secret')],
			put(secret , (NewSecret));
		true ->
			io:format("")
	end,
	buildSecretUpdate(NeighborSecret , I-1).
buildSecretMinMaxAvg(NeighborSecret , I) ->
	{Secret , _ , _} = lists:nth(I , NeighborSecret),
	IsSecret = lists:keysearch(Secret , 1 , get('secret')),
	if
		IsSecret == (false) ->
			NewSecret = [{max,get('number')} | get('secret')],
			put(secret , (NewSecret));
		true ->
			io:format("")
	end,
	buildSecretMinMaxAvg(NeighborSecret , I-1).