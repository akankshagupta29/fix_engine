-module(fix_parser_test).

-include_lib("eunit/include/eunit.hrl").
-include("fix_parser.hrl").
-include("fix_fields.hrl").

-compile([export_all]).

test1_test() ->
   {ok, P} = fix_parser:create("../deps/fix_parser/fix_descr/fix.4.4.xml", [], []),
   {ok, M} = fix_parser:create_msg(P, "8"),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_SenderCompID, "QWERTY_12345678")),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_TargetCompID, "ABCQWE_XYZ")),
   ?assertEqual(ok, fix_parser:set_int32_field(M,  ?FIXFieldTag_MsgSeqNum, 34)),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_TargetSubID, "srv-ivanov_ii1")),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_SendingTime, "20120716-06:00:16.230")),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_OrderID, "1")),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_ClOrdID, "CL_ORD_ID_1234567")),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_ExecID, "FE_1_9494_1")),
   ?assertEqual(ok, fix_parser:set_char_field(M,   ?FIXFieldTag_ExecType, $0)),
   ?assertEqual(ok, fix_parser:set_char_field(M,   ?FIXFieldTag_OrdStatus, $1)),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_Account, "ZUM")),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_Symbol, "RTS-12.12")),
   ?assertEqual(ok, fix_parser:set_char_field(M,   ?FIXFieldTag_Side, $1)),
   ?assertEqual(ok, fix_parser:set_double_field(M, ?FIXFieldTag_OrderQty, 25.0)),
   ?assertEqual(ok, fix_parser:set_double_field(M, ?FIXFieldTag_Price, 135155.0)),
   ?assertEqual(ok, fix_parser:set_char_field(M,   ?FIXFieldTag_TimeInForce, $0)),
   ?assertEqual(ok, fix_parser:set_double_field(M, ?FIXFieldTag_LastQty, 0)),
   ?assertEqual(ok, fix_parser:set_double_field(M, ?FIXFieldTag_LastPx, 0)),
   ?assertEqual(ok, fix_parser:set_double_field(M, ?FIXFieldTag_LeavesQty, 25.0)),
   ?assertEqual(ok, fix_parser:set_double_field(M, ?FIXFieldTag_CumQty, 0)),
   ?assertEqual(ok, fix_parser:set_double_field(M, ?FIXFieldTag_AvgPx, 0)),
   ?assertEqual(ok, fix_parser:set_char_field(M,   ?FIXFieldTag_HandlInst, $1)),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_Text, "COMMENT12")),
   {ok, Fix} = fix_parser:msg_to_str(M, $|),
   Res = {ok, M1, _} = fix_parser:str_to_msg(P, $|, Fix),
   ?assertMatch({ok, _, <<>>}, Res),
   ?assertEqual({ok, "QWERTY_12345678"}, fix_parser:get_string_field(M1, ?FIXFieldTag_SenderCompID)),
   ?assertEqual({ok, "ABCQWE_XYZ"}, fix_parser:get_string_field(M1, ?FIXFieldTag_TargetCompID)),
   ?assertEqual({ok, 34}, fix_parser:get_int32_field(M1, ?FIXFieldTag_MsgSeqNum)),
   ?assertEqual({ok, "srv-ivanov_ii1"}, fix_parser:get_string_field(M1, ?FIXFieldTag_TargetSubID)),
   ?assertEqual({ok, "20120716-06:00:16.230"}, fix_parser:get_string_field(M1, ?FIXFieldTag_SendingTime)),
   ?assertEqual({ok, "1"}, fix_parser:get_string_field(M1, ?FIXFieldTag_OrderID)),
   ?assertEqual({ok, "CL_ORD_ID_1234567"}, fix_parser:get_string_field(M1, ?FIXFieldTag_ClOrdID)),
   ?assertEqual({ok, "FE_1_9494_1"}, fix_parser:get_string_field(M1, ?FIXFieldTag_ExecID)),
   ?assertEqual({ok, $0}, fix_parser:get_char_field(M1, ?FIXFieldTag_ExecType)),
   ?assertEqual({ok, $1}, fix_parser:get_char_field(M1, ?FIXFieldTag_OrdStatus)),
   ?assertEqual({ok, "ZUM"}, fix_parser:get_string_field(M1, ?FIXFieldTag_Account)),
   ?assertEqual({ok, "RTS-12.12"}, fix_parser:get_string_field(M1, ?FIXFieldTag_Symbol)),
   ?assertEqual({ok, $1}, fix_parser:get_char_field(M1, ?FIXFieldTag_Side)),
   ?assertEqual({ok, 25.0}, fix_parser:get_double_field(M1, ?FIXFieldTag_OrderQty)),
   ?assertEqual({ok, 135155.00}, fix_parser:get_double_field(M1, ?FIXFieldTag_Price)),
   ?assertEqual({ok, $0}, fix_parser:get_char_field(M1, ?FIXFieldTag_TimeInForce)),
   ?assertEqual({ok, 0.0}, fix_parser:get_double_field(M1, ?FIXFieldTag_LastQty)),
   ?assertEqual({ok, 0.0}, fix_parser:get_double_field(M1, ?FIXFieldTag_LastPx)),
   ?assertEqual({ok, 25.0}, fix_parser:get_double_field(M1, ?FIXFieldTag_LeavesQty)),
   ?assertEqual({ok, 0.0}, fix_parser:get_double_field(M1, ?FIXFieldTag_CumQty)),
   ?assertEqual({ok, 0.0}, fix_parser:get_double_field(M1, ?FIXFieldTag_AvgPx)),
   ?assertEqual({ok, $1}, fix_parser:get_char_field(M1, ?FIXFieldTag_HandlInst)),
   ?assertEqual({ok, "COMMENT12"}, fix_parser:get_string_field(M1, ?FIXFieldTag_Text)).

test2_test() ->
   {ok, P} = fix_parser:create("../deps/fix_parser/fix_descr/fix.5.0.sp2.xml", [], []),
   {ok, M} = fix_parser:create_msg(P, "AE"),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_ApplVerID, "9")),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_TradeReportID, "121111_1_3999")),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_TradeID, "121111_1_3999")),
   ?assertEqual(ok, fix_parser:set_int32_field(M, ?FIXFieldTag_TradeReportTransType, 0)),
   ?assertEqual(ok, fix_parser:set_int32_field(M, ?FIXFieldTag_TradeReportType, 0)),
   ?assertEqual(ok, fix_parser:set_int32_field(M, ?FIXFieldTag_TrdType, 0)),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_OrigTradeID, "121119_1_3999")),
   ?assertEqual(ok, fix_parser:set_char_field(M, ?FIXFieldTag_ExecType, $F)),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_ExecID, "0")),
   ?assertEqual(ok, fix_parser:set_int32_field(M, ?FIXFieldTag_PriceType, 2)),
   {ok, RootPartyID1} = fix_parser:add_group(M, ?FIXFieldTag_NoRootPartyIDs),
   ?assertEqual(ok, fix_parser:set_string_field(RootPartyID1, ?FIXFieldTag_RootPartyID, "XYZ")),
   ?assertEqual(ok, fix_parser:set_char_field(RootPartyID1, ?FIXFieldTag_RootPartyIDSource, $D)),
   ?assertEqual(ok, fix_parser:set_int32_field(RootPartyID1, ?FIXFieldTag_RootPartyRole, 16)),
   {ok, RootPartyID2} = fix_parser:add_group(M, ?FIXFieldTag_NoRootPartyIDs),
   ?assertEqual(ok, fix_parser:set_string_field(RootPartyID2, ?FIXFieldTag_RootPartyID, "XYZA")),
   ?assertEqual(ok, fix_parser:set_char_field(RootPartyID2, ?FIXFieldTag_RootPartyIDSource, $E)),
   ?assertEqual(ok, fix_parser:set_int32_field(RootPartyID2, ?FIXFieldTag_RootPartyRole, 17)),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_MarketID, "OTC")),
   {ok, SecAltID} = fix_parser:add_group(M, ?FIXFieldTag_NoSecurityAltID),
   ?assertEqual(ok, fix_parser:set_string_field(SecAltID, ?FIXFieldTag_SecurityAltID, "SYMBOL_ABC")),
   ?assertEqual(ok, fix_parser:set_string_field(SecAltID, ?FIXFieldTag_SecurityAltID, "M")),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_CFICode, "MRCSXX")),
   ?assertEqual(ok, fix_parser:set_int32_field(M, ?FIXFieldTag_QtyType, 0)),
   ?assertEqual(ok, fix_parser:set_double_field(M, ?FIXFieldTag_LastQty, 110000)),
   ?assertEqual(ok, fix_parser:set_double_field(M, ?FIXFieldTag_LastQty, 31.12)),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_Currency, "USD")),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_TradeDate, "20121119")),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_TransactTime, "20121119-08:33:57")),
   ?assertEqual(ok, fix_parser:set_string_field(M, ?FIXFieldTag_SettlType, "2")),
   {ok, SideGrp} = fix_parser:add_group(M, ?FIXFieldTag_NoSides),
   ?assertEqual(ok, fix_parser:set_char_field(SideGrp, ?FIXFieldTag_Side, $1)),
   ?assertEqual(ok, fix_parser:set_string_field(SideGrp, ?FIXFieldTag_OrderID, "ORD_1234567")),
   ?assertEqual(ok, fix_parser:set_string_field(SideGrp, ?FIXFieldTag_ClOrdID, "CLORDID_1234567")),
   ?assertEqual(ok, fix_parser:set_char_field(SideGrp, ?FIXFieldTag_OrdType, $2)),
   ?assertEqual(ok, fix_parser:set_double_field(SideGrp, ?FIXFieldTag_Price, 31.12)),
   ?assertEqual(ok, fix_parser:set_double_field(SideGrp, ?FIXFieldTag_OrderQty, 5000000)),
   ?assertEqual(ok, fix_parser:set_double_field(SideGrp, ?FIXFieldTag_LeavesQty, 444000)),
   ?assertEqual(ok, fix_parser:set_double_field(SideGrp, ?FIXFieldTag_CumQty, 1111000)),

   {ok, PartyGrp1} = fix_parser:add_group(SideGrp, ?FIXFieldTag_NoPartyIDs),
   ?assertEqual(ok, fix_parser:set_string_field(PartyGrp1, ?FIXFieldTag_PartyID, "FX_FF_FLXX")),
   ?assertEqual(ok, fix_parser:set_char_field(PartyGrp1, ?FIXFieldTag_PartyIDSource, $D)),
   ?assertEqual(ok, fix_parser:set_int32_field(PartyGrp1, ?FIXFieldTag_PartyRole, 38)),

   {ok, PartyGrp2} = fix_parser:add_group(SideGrp, ?FIXFieldTag_NoPartyIDs),
   ?assertEqual(ok, fix_parser:set_string_field(PartyGrp2, ?FIXFieldTag_PartyID, "FX_FF_FLYY")),
   ?assertEqual(ok, fix_parser:set_char_field(PartyGrp2, ?FIXFieldTag_PartyIDSource, $D)),
   ?assertEqual(ok, fix_parser:set_int32_field(PartyGrp2, ?FIXFieldTag_PartyRole, 41)),

   ?assertEqual(ok, fix_parser:set_double_field(M, ?FIXFieldTag_GrossTradeAmt, 357333.12)).

test3_test() ->
   Logon = <<"8=FIX.4.4\0019=139\00135=A\00149=dmelnikov1_test_robot1\00156=crossing_engine\00134=1\00152=20130130-14:50:33.448\00198=0\001108=30\001141=Y\001553=dmelnikov\001554=xlltlib(1.0):dmelnikov\00110=196\001">>,
   Res = fix_parser:get_session_id(Logon, 1),
   ?assertEqual({ok, "dmelnikov1_test_robot1", "crossing_engine"}, Res).
