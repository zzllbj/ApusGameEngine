// Translated from STEAM SDK headers

// Copyright (C) 2011 Apus Software. Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit steamAPI;
interface
 var
  steamAvailable:boolean=false;   // Is API available?
  steamID:int64;
  steamGameLang:PChar;

 type
  int32=integer;
  Pint32=^int32;
  uint32=cardinal;
  float=single;
  SteamAPICall_t=int64;
  SteamLeaderboard_t=int64;
  SteamLeaderboardEntries_t=int64;
  UGCHandle_t=int64;
  HAuthTicket=uint32;
  HSteamuser=integer;
  HSteamPipe=integer;

  // Own functions
  procedure InitSteamAPI;
  procedure DoneSteamAPI;

  // �������� ����� ��� �������� ��� ������� (HEX-������)
  function GetSteamAuthTicket:string;

  // Imported SteamAPI functions

  function SteamAPI_Init():boolean; cdecl; external 'steam_api.dll';
  procedure SteamAPI_Shutdown(); cdecl; external 'steam_api.dll';

  function SteamInternal_CreateInterface(ver:PChar):pointer; cdecl; external 'steam_api.dll';
  function SteamAPI_GetHSteamUser:HSteamUser;  cdecl; external 'steam_api.dll';
  function SteamAPI_GetHSteamPipe:HSteamPipe;  cdecl; external 'steam_api.dll';
  function SteamAPI_ISteamClient_GetISteamUser(steamClient:pointer;hSteamUser:HSteamUser;
    hSteamPipe:HSteamPipe;const pchVersion:PChar):pointer;  cdecl; external 'steam_api.dll';
  function SteamAPI_ISteamClient_GetISteamApps(steamClient:pointer;hSteamUser:HSteamUser;
    hSteamPipe:HSteamPipe;const pchVersion:PChar):pointer; cdecl; external 'steam_api.dll';
  function SteamAPI_ISteamClient_GetISteamUserStats(steamClient:pointer;hSteamUser:HSteamUser;
    hSteamPipe:HSteamPipe;const pchVersion:PChar):pointer; cdecl; external 'steam_api.dll';

  function SteamAPI_ISteamUser_GetAuthSessionTicket(steamUser:pointer;pTicket:pointer;cbMaxTicket:integer;
    out pcbTicket:Cardinal):HAuthTicket; cdecl; external 'steam_api.dll';

  function SteamAPI_ISteamUser_GetSteamID(steamUser:pointer):int64; cdecl; external 'steam_api.dll';
  function SteamAPI_ISteamApps_GetCurrentGameLanguage(steamApps:pointer):PChar; cdecl; external 'steam_api.dll';

  procedure SteamAPI_RunCallbacks; cdecl; external 'steam_api.dll';
  procedure SteamAPI_RegisterCallback(callbackbase:pointer;iCallback:integer); cdecl; external 'steam_api.dll';

  function SteamAPI_ISteamUserStats_SetAchievement(steamUserStats:pointer;const pchName:PChar):boolean; cdecl; external 'steam_api.dll';
  function SteamAPI_ISteamUserStats_ClearAchievement(steamUserStats:pointer;const pchName:PChar):boolean; cdecl; external 'steam_api.dll';
  function SteamAPI_ISteamUserStats_IndicateAchievementProgress(steamUserStats:pointer;const pchName:PChar;
    nCurProgress,nMaxProgress:cardinal):boolean; cdecl; external 'steam_api.dll';

implementation
 uses windows,SysUtils,MyServis,EventMan;
 type
  PMicroTxnAuthorizationResponse_t=^MicroTxnAuthorizationResponse_t;
  MicroTxnAuthorizationResponse_t=record
    m_unAppID:integer;        // AppID for this microtransaction
    m_ulOrderID:int64;        // OrderID provided for the microtransaction
    m_bAuthorized:byte;    // if user authorized transaction
  end;

 const
  STEAMCLIENT_VERSION='SteamClient017';
  STEAMUSER_VERSION='SteamUser019';
  STEAMAPPS_VERSION='STEAMAPPS_INTERFACE_VERSION008';
  STEAMUSERSTAT_VERSION='STEAMUSERSTATS_INTERFACE_VERSION011';

  k_iSteamUserCallbacks = 100;

 var
  steamClient,steamUser,steamApps,steamUserStats:pointer;
  callbackVMT:array[0..5] of pointer;
  callbackObj:array[0..5] of pointer;

 // Callback function
 {$W+}
 procedure OnMicroTxnAuthorization(param:PMicroTxnAuthorizationResponse_t); stdcall;
  begin
   LogMessage('Transaction: '+IntToStr(param.m_ulOrderID)+' code:'+IntToStr(param.m_bAuthorized));
   Signal('STEAM\MicroTxnAuthorization\'+IntToStr(param.m_ulOrderID),param.m_bAuthorized);
  end;

 function GetSteamAuthTicket:string;
  var
   ticket:array[0..1023] of byte;
   size:cardinal;
  begin
   result:='';
   ASSERT(steamAvailable);
   SteamAPI_ISteamUser_GetAuthSessionTicket(steamUser,@ticket,sizeof(ticket),size);
   result:=EncodeHex(@ticket,size);
  end;

 procedure InitSteamAPI;
  var
   pipe,user:integer;
   p:MicroTxnAuthorizationResponse_t;
  begin
   steamAvailable:=SteamAPI_Init;
   if not steamAvailable then begin
    LogMessage('STEAM not available');
    exit;
   end;
   LogMessage('STEAM API available');
   user:=SteamAPI_GetHSteamUser;
   pipe:=SteamAPI_GetHSteamPipe;
   steamClient:=SteamInternal_CreateInterface(STEAMCLIENT_VERSION);
   steamUser:=SteamAPI_ISteamClient_GetISteamUser(steamClient,user,pipe,STEAMUSER_VERSION);
   steamApps:=SteamAPI_ISteamClient_GetISteamApps(steamClient,user,pipe,STEAMAPPS_VERSION);
   steamUserStats:=SteamAPI_ISteamClient_GetISteamUserStats(steamClient,user,pipe,STEAMUSERSTAT_VERSION);
//   ForceLogMessage(Format('steamClient=%x steamUser=%x, user=%d pipe=%d',[cardinal(steamClient),cardinal(steamUser),user,pipe]));
   steamID:=SteamAPI_ISteamUser_GetSteamID(steamUser);
   steamGameLang:=SteamAPI_ISteamApps_GetCurrentGameLanguage(steamApps);
   LogMessage('SteamID='+IntToStr(steamID)+' GameLang='+string(steamGameLang));

   // Register callbacks
{   SteamAPI_RegisterCallback(@callback,k_iSteamUserCallbacks + 1);
   SteamAPI_RegisterCallback(@callback,k_iSteamUserCallbacks + 2);
   SteamAPI_RegisterCallback(@callback,k_iSteamUserCallbacks + 3);
   SteamAPI_RegisterCallback(@callback,k_iSteamUserCallbacks + 17);
   SteamAPI_RegisterCallback(@callback,k_iSteamUserCallbacks + 43);
   SteamAPI_RegisterCallback(@callback,k_iSteamUserCallbacks + 54);}

   callbackVMT[1]:=@OnMicroTxnAuthorization;
   callbackObj[0]:=@callbackVMT;
   SteamAPI_RegisterCallback(@callbackObj,k_iSteamUserCallbacks + 52);
  end;

 procedure DoneSteamAPI;
  begin
   if steamAvailable then SteamAPI_Shutdown;
  end;

initialization
end.
