unit LoggerPro.UDPSyslogAppender;
{ <@abstract(Contains the Syslog Logger (RFC 5424))
  @author(https://github.com/nurettin)
  @author(Daniele Teti)
}

interface

uses
  LoggerPro,
  IdBaseComponent,
  IdComponent,
  IdUDPBase,
  IdUDPClient,
  IdGlobal;

type
  TLoggerProUDPSyslogAppender = class(TLoggerProAppenderBase)
  private
    FLoggerProSyslogAppenderClient: TIdUDPClient;
    FIP: string;
    FPort: Integer;
    FHostName: string;
    FUserName: string;
    FApplication: string;
    FVersion: string;
    FProcID: string;
    FUnixLineBreaks: Boolean;
    FUTF8BOM: Boolean;

  public
    constructor Create(pIP: string; pPort: Integer; pHostName: string; pUserName: string; pApplication: string;
      pVersion: string; pProcID: string; pUnixLineBreaks: Boolean; pUTF8BOM: Boolean = False); reintroduce;
    procedure Setup; override;
    procedure TearDown; override;
    procedure WriteLog(const aLogItem: TLogItem); override;

    property IP: string read FIP write FIP;
    property Port: Integer read FPort write FPort;
    property HostName: string read FHostName write FHostName;
    property UserName: string read FUserName write FUserName;
    property Application: string read FApplication write FApplication;
    property Version: string read FVersion write FVersion;
    property ProcID: string read FProcID write FProcID;
    property UnixLineBreaks: Boolean read FUnixLineBreaks write FUnixLineBreaks;
  end;

  TLoggerProUDPSyslogPacket = class
  strict private
    FPriority: string;
    FVersion: string;
    FTimestamp: string;
    FHostName: string;
    FUserName: string;
    FApplication: string;
    FProcID: string;
    FThreadID: string;
    FMessageID: string;
    FMessageData: string;
    FUnixLineBreaks: Boolean;
    FUTF8BOM: Boolean;
    function GetSyslogData: string;
  public
    constructor Create(pLogItem: TLogItem; pHostName: string; pUserName: string; pApplication: string; pVersion: string;
      pProcID: string; pUnixLineBreaks: Boolean; pUTF8BOM: Boolean = False);
    property SyslogData: string read GetSyslogData;
  end;

implementation

uses
  System.DateUtils,
  System.SysUtils;
{ TLoggerProUDPSyslogAppender }

constructor TLoggerProUDPSyslogAppender.Create(pIP: string; pPort: Integer; pHostName: string; pUserName: string;
  pApplication: string; pVersion: string; pProcID: string; pUnixLineBreaks: Boolean; pUTF8BOM: Boolean);
begin
  inherited Create;
  FIP := pIP;
  FPort := pPort;
  FHostName := pHostName;
  FUserName := pUserName;
  FApplication := pApplication;
  FVersion := pVersion;
  FProcID := pProcID;
  FUnixLineBreaks := pUnixLineBreaks;
  FUTF8BOM := pUTF8BOM;
end;

procedure TLoggerProUDPSyslogAppender.Setup;
begin
  inherited;
  FLoggerProSyslogAppenderClient := TIdUDPClient.Create(nil);
end;

procedure TLoggerProUDPSyslogAppender.TearDown;
begin
  FLoggerProSyslogAppenderClient.Free;
  inherited;
end;

procedure TLoggerProUDPSyslogAppender.WriteLog(const aLogItem: TLogItem);
var
  lPacket: TLoggerProUDPSyslogPacket;
begin
  inherited;
  lPacket := TLoggerProUDPSyslogPacket.Create(aLogItem, FHostName, FUserName, FApplication, FVersion, FProcID,
    FUnixLineBreaks, FUTF8BOM);
  try
    {$IF CompilerVersion >= 24}
    FLoggerProSyslogAppenderClient.Broadcast(lPacket.SyslogData, FPort, FIP, IndyTextEncoding_UTF8);
    {$ELSE}
    FLoggerProSyslogAppenderClient.Broadcast(lPacket.SyslogData, FPort, FIP, TIdTextEncoding.UTF8);
    {$IFEND}
  finally
    lPacket.Free;
  end;
end;

{ TLoggerProUDPSyslogPacket }

function RFC5424Priority(pFacility, pSeverity: Integer): string;
begin
  Result := '<' + IntToStr(pFacility * 8 + pSeverity) + '>';
end;

constructor TLoggerProUDPSyslogPacket.Create(pLogItem: TLogItem; pHostName: string; pUserName: string;
  pApplication: string; pVersion: string; pProcID: string; pUnixLineBreaks: Boolean; pUTF8BOM: Boolean);
begin
  case pLogItem.LogType of
    TLogType.Debug:
      FPriority := RFC5424Priority(1, 7);
    TLogType.Info:
      FPriority := RFC5424Priority(1, 6);
    TLogType.Warning:
      FPriority := RFC5424Priority(1, 5);
    TLogType.Error:
      FPriority := RFC5424Priority(1, 4);
  end;
  {$IF Compilerversion >= 24}
  if pLogItem.LogMessage.Contains('Access Violation') then
  {$ELSE}
  if Pos('Access Violation', pLogItem.LogMessage) > 0 then
  {$IFEND}
    FPriority := RFC5424Priority(1, 3);
  FApplication := pApplication;
  FVersion := pVersion;
  {$IF Compilerversion >= 24}
  FTimestamp := DateToISO8601(pLogItem.Timestamp);
  {$ELSE}
  DateTimeToString(FTimestamp, 'yyyy-mm-dd', pLogItem.Timestamp);
  {$IFEND}
  FHostName := pHostName;
  FUserName := pUserName;
  FApplication := pApplication;
  FVersion := pVersion;
  FProcID := pProcID;
  FThreadID := IntToStr(pLogItem.ThreadID);
  FMessageID := pLogItem.LogTag;
  FUnixLineBreaks := pUnixLineBreaks;
  if FUnixLineBreaks then
    {$IF Compilerversion >= 24}
    FMessageData := pLogItem.LogMessage.Replace(sLineBreak, '#10', [rfReplaceAll])
    {$ELSE}
    FMessageData := StringReplace(pLogItem.LogMessage, sLineBreak, '#10', [rfReplaceAll])
    {$IFEND}
  else
    FMessageData := pLogItem.LogMessage;
  FUTF8BOM := pUTF8BOM;
end;

function TLoggerProUDPSyslogPacket.GetSyslogData: string;
const
  IANAVersion = '1';
begin
  Result :=
  // NOT; RFC 5424 6.2 HEADER
    FPriority + IANAVersion + ' ' + FTimestamp + ' ' + FHostName + ' ' + FApplication + ' ' + FProcID + ' ' + FMessageID
  // NOT; RFC 5424, 6.5 ex 1 no structured data
    + ' - ' + iif(FUTF8BOM, #$EF#$BB#$BF) + FUserName + ' ' + FVersion + ' '
    + FThreadID + ' ' + FMessageData;
  // NOT; RFC 5424 structured data, uncomment and use if needed
  // + ' [MySDID@1 ' + 'UserName="' + FUserName + '" Version="' + FVersion + '" ThreadId="' + FThreadID + '" MessageData="' + FMessageData + '"]' + ...;
end;

end.
