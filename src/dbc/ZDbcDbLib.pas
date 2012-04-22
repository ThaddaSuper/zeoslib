{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{               DBLib Connectivity Classes                }
{                                                         }
{        Originally written by Janos Fegyverneki          }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2006 Zeos Development Group       }
{                                                         }
{ License Agreement:                                      }
{                                                         }
{ This library is distributed in the hope that it will be }
{ useful, but WITHOUT ANY WARRANTY; without even the      }
{ implied warranty of MERCHANTABILITY or FITNESS FOR      }
{ A PARTICULAR PURPOSE.  See the GNU Lesser General       }
{ Public License for more details.                        }
{                                                         }
{ The source code of the ZEOS Libraries and packages are  }
{ distributed under the Library GNU General Public        }
{ License (see the file COPYING / COPYING.ZEOS)           }
{ with the following  modification:                       }
{ As a special exception, the copyright holders of this   }
{ library give you permission to link this library with   }
{ independent modules to produce an executable,           }
{ regardless of the license terms of these independent    }
{ modules, and to copy and distribute the resulting       }
{ executable under terms of your choice, provided that    }
{ you also meet, for each linked independent module,      }
{ the terms and conditions of the license of that module. }
{ An independent module is a module which is not derived  }
{ from or based on this library. If you modify this       }
{ library, you may extend this exception to your version  }
{ of the library, but you are not obligated to do so.     }
{ If you do not wish to do so, delete this exception      }
{ statement from your version.                            }
{                                                         }
{                                                         }
{ The project web site is located on:                     }
{   http://zeos.firmos.at  (FORUM)                        }
{   http://zeosbugs.firmos.at (BUGTRACKER)                }
{   svn://zeos.firmos.at/zeos/trunk (SVN Repository)      }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{   http://www.zeoslib.sourceforge.net                    }
{                                                         }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZDbcDbLib;

interface

{$I ZDbc.inc}

uses
{$IFDEF FPC}
  {$IFDEF WIN32}
    Comobj,
  {$ENDIF}
{$ENDIF}
  Types, Classes, ZDbcConnection, ZDbcIntfs, ZCompatibility, ZDbcLogging,
  ZPlainDbLibDriver, ZTokenizer, ZGenericSqlAnalyser, ZURL, ZPlainDriver;

type
  {** Implements DBLib Database Driver. }
  TZDBLibDriver = class(TZAbstractDriver)
  private
    FMSSqlPlainDriver: IZDBLibPlainDriver;
    FSybasePlainDriver: IZDBLibPlainDriver;
  protected
    function GetPlainDriver(const Url: TZURL): IZPlainDriver; override;
  public
    constructor Create;
    function Connect(const Url: TZURL): IZConnection; override;

    function GetSupportedProtocols: TStringDynArray; override;
    function GetMajorVersion: Integer; override;
    function GetMinorVersion: Integer; override;

    function GetTokenizer: IZTokenizer; override;
    function GetStatementAnalyser: IZStatementAnalyser; override;
  end;

  {** Represents a DBLib specific connection interface. }
  IZDBLibConnection = interface (IZConnection)
    ['{6B0662A2-FF2A-4415-B6B0-AAC047EA0671}']

    function GetPlainDriver: IZDBLibPlainDriver;
    function GetConnectionHandle: PDBPROCESS;
    procedure InternalExecuteStatement(const SQL: string);
    procedure CheckDBLibError(LogCategory: TZLoggingCategory; const LogMessage: string);
  end;

  {** Implements a generic DBLib Connection. }
  TZDBLibConnection = class(TZAbstractConnection, IZDBLibConnection)
  private
    procedure ReStartTransactionSupport;
    procedure InternalSetTransactionIsolation(Level: TZTransactIsolationLevel);
  protected
    FHandle: PDBPROCESS;
    procedure InternalCreate; override;
    procedure InternalExecuteStatement(const SQL: string); virtual;
    procedure InternalLogin; virtual;
    function GetPlainDriver: IZDBLibPlainDriver;
    function GetConnectionHandle: PDBPROCESS;
    procedure CheckDBLibError(LogCategory: TZLoggingCategory; const LogMessage: string); virtual;
    procedure StartTransaction; virtual;
  public
    destructor Destroy; override;

    function CreateRegularStatement(Info: TStrings): IZStatement; override;
    function CreatePreparedStatement(const SQL: string; Info: TStrings):
      IZPreparedStatement; override;
    function CreateCallableStatement(const SQL: string; Info: TStrings):
      IZCallableStatement; override;

    function NativeSQL(const SQL: string): string; override;

    procedure SetAutoCommit(AutoCommit: Boolean); override;
    procedure SetTransactionIsolation(Level: TZTransactIsolationLevel); override;

    procedure Commit; override;
    procedure Rollback; override;

    procedure Open; override;
    procedure Close; override;

    procedure SetReadOnly(ReadOnly: Boolean); override;

    procedure SetCatalog(const Catalog: string); override;
    function GetCatalog: string; override;

    function GetWarnings: EZSQLWarning; override;
    procedure ClearWarnings; override;
  end;

var
  {** The common driver manager object. }
  DBLibDriver: IZDriver;

implementation

uses
  SysUtils, ZSysUtils, ZMessages, ZDbcUtils, ZDbcDbLibStatement,
  ZDbcDbLibMsSqlMetadata, ZSybaseToken, ZSybaseAnalyser,
  ZDbcDbLibSybaseMetadata{$IFDEF FPC}, ZClasses{$ENDIF};

{ TZDBLibDriver }

{**
  Constructs this object with default properties.
}
constructor TZDBLibDriver.Create;
begin
  FMSSqlPlainDriver := TZDBLibMSSQL7PlainDriver.Create;
  FSybasePlainDriver := TZDBLibSybaseASE125PlainDriver.Create;
end;

function TZDBLibDriver.GetPlainDriver(const Url: TZURL): IZPlainDriver;
begin
  if Url.Protocol = FMSSqlPlainDriver.GetProtocol then
    Result := FMSSqlPlainDriver;
  if Url.Protocol = FSybasePlainDriver.GetProtocol then
    Result := FSybasePlainDriver;
  Result.Initialize(Url.LibLocation);
end;

{**
  Get a name of the supported subprotocol.
}
function TZDBLibDriver.GetSupportedProtocols: TStringDynArray;
begin
  SetLength(Result, 2);
  Result[0] := FSybasePlainDriver.GetProtocol;
  Result[1] := FMSSqlPlainDriver.GetProtocol;
end;

{**
  Attempts to make a database connection to the given URL.
}
function TZDBLibDriver.Connect(const Url: TZURL): IZConnection;
begin
  Result := TZDBLibConnection.Create(Url);
end;

{**
  Gets the driver's major version number. Initially this should be 1.
  @return this driver's major version number
}
function TZDBLibDriver.GetMajorVersion: Integer;
begin
  Result := 1;
end;

{**
  Gets the driver's minor version number. Initially this should be 0.
  @return this driver's minor version number
}
function TZDBLibDriver.GetMinorVersion: Integer;
begin
  Result := 0;
end;

{**
  Gets a SQL syntax tokenizer.
  @returns a SQL syntax tokenizer object.
}
function TZDBLibDriver.GetTokenizer: IZTokenizer;
begin
  if Tokenizer = nil then
    Tokenizer := TZSybaseTokenizer.Create;
  Result := Tokenizer;
end;

{**
  Creates a statement analyser object.
  @returns a statement analyser object.
}
function TZDBLibDriver.GetStatementAnalyser: IZStatementAnalyser;
begin
  if Analyser = nil then
    Analyser := TZSybaseStatementAnalyser.Create;
  Result := Analyser;
end;

{ TZDBLibConnection }

{**
  Constructs this object and assignes the main properties.
}
procedure TZDBLibConnection.InternalCreate;
begin
  if Url.Protocol = 'mssql' then
    FMetadata := TZMsSqlDatabaseMetadata.Create(Self, Url)
  else if Url.Protocol = 'sybase' then
    FMetadata := TZSybaseDatabaseMetadata.Create(Self, Url)
  else
    FMetadata := nil;

  FHandle := nil;
end;

{**
  Destroys this object and cleanups the memory.
}
destructor TZDBLibConnection.Destroy;
begin
  Close;
  inherited Destroy;
end;

{**
  Executes simple statements internally.
}
procedure TZDBLibConnection.InternalExecuteStatement(const SQL: string);
var
  LSQL: string;
begin
  FHandle := GetConnectionHandle;
  if GetPlainDriver.dbCancel(FHandle) <> DBSUCCEED then
    CheckDBLibError(lcExecute, SQL);
  if GetPlainDriver.GetProtocol = 'mssql' then
    LSQL := StringReplace(Sql, '\'#13, '\\'#13, [rfReplaceAll])
  else
    LSQL := SQL;
  {$IFDEF DELPHI12_UP}
    if GetPlainDriver.dbcmd(FHandle, PAnsiChar(UTF8String(LSql))) <> DBSUCCEED then
  {$ELSE}
  if GetPlainDriver.dbcmd(FHandle, PAnsiChar(LSql)) <> DBSUCCEED then
  {$ENDIF}
    CheckDBLibError(lcExecute, LSQL);
  if GetPlainDriver.dbsqlexec(FHandle) <> DBSUCCEED then
    CheckDBLibError(lcExecute, LSQL);
  repeat
    GetPlainDriver.dbresults(FHandle);
    GetPlainDriver.dbcanquery(FHandle);
  until GetPlainDriver.dbmorecmds(FHandle) = DBFAIL;
  CheckDBLibError(lcExecute, LSQL);
  DriverManager.LogMessage(lcExecute, PlainDriver.GetProtocol, LSQL);
end;

{**
  Login procedure can be overriden for special settings.
}
procedure TZDBLibConnection.InternalLogin;
var
  Loginrec: PLOGINREC;
  LogMessage: string;
  S: string;
begin
  LogMessage := Format('CONNECT TO "%s"', [HostName]);
  LoginRec := GetPLainDriver.dbLogin;
  try
//Common parameters
    S := Info.Values['workstation'];
    if S <> '' then
         {$IFDEF DELPHI12_UP}
         GetPlainDriver.dbSetLHost(LoginRec, PAnsiChar(UTF8String(S)));
         {$ELSE}
         GetPlainDriver.dbSetLHost(LoginRec, PAnsiChar(S));
         {$ENDIF}
    S := Info.Values['appname'];
    if S <> '' then
         {$IFDEF DELPHI12_UP}
         GetPlainDriver.dbSetLApp(LoginRec, PAnsiChar(UTF8String(S)));
         {$ELSE}
         GetPlainDriver.dbSetLApp(LoginRec, PAnsiChar(S));
          {$ENDIF}
    S := Info.Values['language'];
    if S <> '' then
         {$IFDEF DELPHI12_UP}
         GetPlainDriver.dbSetLNatLang(LoginRec, PAnsiChar(UTF8String(S)));
         {$ELSE}
         GetPlainDriver.dbSetLNatLang(LoginRec, PAnsiChar(S));
         {$ENDIF}
    S := Info.Values['timeout'];
    if S <> '' then
      GetPlainDriver.dbSetLoginTime(StrToIntDef(S, 60));

//mssql specific parameters
    if PlainDriver.GetProtocol = 'mssql' then
    begin
      if StrToBoolEx(Info.Values['NTAuth']) or StrToBoolEx(Info.Values['trusted'])
        or StrToBoolEx(Info.Values['secure']) then
      begin
        GetPlainDriver.dbsetlsecure(LoginRec);
        LogMessage := LogMessage + ' USING WINDOWS AUTHENTICATION';
      end
      else
      begin
        {$IFDEF DELPHI12_UP}
        GetPlainDriver.dbsetluser(LoginRec, PAnsiChar(UTF8String(User)));
        GetPlainDriver.dbsetlpwd(LoginRec, PAnsiChar(UTF8String(Password)));
        {$ELSE}
        GetPlainDriver.dbsetluser(LoginRec, PAnsiChar(User));
        GetPlainDriver.dbsetlpwd(LoginRec, PAnsiChar(Password));
        {$ENDIF}
        LogMessage := LogMessage + Format(' AS USER "%s"', [User]);
      end;
    end;

//sybase specific parameters
    if PlainDriver.GetProtocol = 'sybase' then
    begin
      S := Info.Values['codepage'];
      if S <> '' then
            {$IFDEF DELPHI12_UP}
            GetPlainDriver.dbSetLCharSet(LoginRec, PAnsiChar(UTF8String(S)));
            {$ELSE}
            GetPlainDriver.dbSetLCharSet(LoginRec, PAnsiChar(S));
            {$ENDIF}
      {$IFDEF DELPHI12_UP}
      GetPlainDriver.dbsetluser(LoginRec, PAnsiChar(UTF8String(User)));
      GetPlainDriver.dbsetlpwd(LoginRec, PAnsiChar(UTF8String(Password)));
      {$ELSE}
      GetPLainDriver.dbsetluser(LoginRec, PAnsiChar(User));
      GetPLainDriver.dbsetlpwd(LoginRec, PAnsiChar(Password));
      {$ENDIF}
      LogMessage := LogMessage + Format(' AS USER "%s"', [User]);
    end;

    CheckDBLibError(lcConnect, LogMessage);
    {$IFDEF DELPHI12_UP}
    FHandle := GetPlainDriver.dbOpen(LoginRec, PAnsiChar(UTF8String(HostName)));
    {$ELSE}
    FHandle := GetPlainDriver.dbOpen(LoginRec, PAnsiChar(HostName));
    {$ENDIF}
    CheckDBLibError(lcConnect, LogMessage);
    DriverManager.LogMessage(lcConnect, PlainDriver.GetProtocol, LogMessage);
  finally
    GetPLainDriver.dbLoginFree(LoginRec);
  end;
end;

function TZDBLibConnection.GetPlainDriver: IZDBLibPlainDriver;
begin
  Result := PlainDriver as IZDBLibPlainDriver;
end;

function TZDBLibConnection.GetConnectionHandle: PDBPROCESS;
begin
  if PlainDriver.GetProtocol = 'mssql' then
    if GetPlainDriver.dbDead(FHandle) then
    begin
      Closed := True;
      Open;
    end;
  Result := FHandle;
end;

procedure TZDBLibConnection.CheckDBLibError(LogCategory: TZLoggingCategory; const LogMessage: string);
begin
  try
    GetPlainDriver.CheckError;
  except
    on E: Exception do
    begin
      DriverManager.LogError(LogCategory, PlainDriver.GetProtocol, LogMessage, 0, E.Message);
      raise;
    end;
  end;
end;

{**
  Starts a transaction support.
}
procedure TZDBLibConnection.ReStartTransactionSupport;
begin
  if Closed then
    Exit;

  if not (AutoCommit or (GetTransactionIsolation = tiNone)) then
    StartTransaction;
end;

{**
  Opens a connection to database server with specified parameters.
}
procedure TZDBLibConnection.Open;
var
  LogMessage: string;
begin
   if not Closed then
      Exit;

  InternalLogin;

  LogMessage := Format('USE %s', [Database]);
  {$IFDEF DELPHI12_UP}
  if GetPlainDriver.dbUse(FHandle, PAnsiChar(UTF8String(Database))) <> DBSUCCEED then
  {$ELSE}
  if GetPlainDriver.dbUse(FHandle, PAnsiChar(Database)) <> DBSUCCEED then
  {$ENDIF}
    CheckDBLibError(lcConnect, LogMessage);
  DriverManager.LogMessage(lcConnect, PlainDriver.GetProtocol, LogMessage);

  LogMessage := 'set textlimit=2147483647';
  if GetPlainDriver.dbsetopt(FHandle, DBTEXTLIMIT, '2147483647') <> DBSUCCEED then
    CheckDBLibError(lcConnect, LogMessage);
  DriverManager.LogMessage(lcConnect, PlainDriver.GetProtocol, LogMessage);

  InternalExecuteStatement('set textsize 2147483647 set quoted_identifier on');

  inherited Open;

  InternalSetTransactionIsolation(GetTransactionIsolation);
  ReStartTransactionSupport;
end;

{**
  Creates a <code>Statement</code> object for sending
  SQL statements to the database.
  SQL statements without parameters are normally
  executed using Statement objects. If the same SQL statement
  is executed many times, it is more efficient to use a
  <code>PreparedStatement</code> object.
  <P>
  Result sets created using the returned <code>Statement</code>
  object will by default have forward-only type and read-only concurrency.

  @return a new Statement object
}
function TZDBLibConnection.CreateRegularStatement(Info: TStrings):
  IZStatement;
begin
  if IsClosed then
     Open;
  Result := TZDBLibStatement.Create(Self, Info);
end;

{**
  Creates a <code>PreparedStatement</code> object for sending
  parameterized SQL statements to the database.

  A SQL statement with or without IN parameters can be
  pre-compiled and stored in a PreparedStatement object. This
  object can then be used to efficiently execute this statement
  multiple times.

  <P><B>Note:</B> This method is optimized for handling
  parametric SQL statements that benefit from precompilation. If
  the driver supports precompilation,
  the method <code>prepareStatement</code> will send
  the statement to the database for precompilation. Some drivers
  may not support precompilation. In this case, the statement may
  not be sent to the database until the <code>PreparedStatement</code> is
  executed.  This has no direct effect on users; however, it does
  affect which method throws certain SQLExceptions.

  Result sets created using the returned PreparedStatement will have
  forward-only type and read-only concurrency, by default.

  @param sql a SQL statement that may contain one or more '?' IN
    parameter placeholders
  @param Info a statement parameters.
  @return a new PreparedStatement object containing the
    pre-compiled statement
}
function TZDBLibConnection.CreatePreparedStatement(
  const SQL: string; Info: TStrings): IZPreparedStatement;
begin
  if IsClosed then
     Open;
  Result := TZDBLibPreparedStatementEmulated.Create(Self, SQL, Info);
end;

{**
  Creates a <code>CallableStatement</code> object for calling
  database stored procedures.
  The <code>CallableStatement</code> object provides
  methods for setting up its IN and OUT parameters, and
  methods for executing the call to a stored procedure.

  <P><B>Note:</B> This method is optimized for handling stored
  procedure call statements. Some drivers may send the call
  statement to the database when the method <code>prepareCall</code>
  is done; others
  may wait until the <code>CallableStatement</code> object
  is executed. This has no
  direct effect on users; however, it does affect which method
  throws certain SQLExceptions.

  Result sets created using the returned CallableStatement will have
  forward-only type and read-only concurrency, by default.

  @param sql a SQL statement that may contain one or more '?'
    parameter placeholders. Typically this  statement is a JDBC
    function call escape string.
  @param Info a statement parameters.
  @return a new CallableStatement object containing the
    pre-compiled SQL statement
}
function TZDBLibConnection.CreateCallableStatement(
  const SQL: string; Info: TStrings): IZCallableStatement;
begin
  if IsClosed then
     Open;
  Result := TZDBLibCallableStatement.Create(Self, SQL, Info);
end;

{**
  Converts the given SQL statement into the system's native SQL grammar.
  A driver may convert the JDBC sql grammar into its system's
  native SQL grammar prior to sending it; this method returns the
  native form of the statement that the driver would have sent.

  @param sql a SQL statement that may contain one or more '?'
    parameter placeholders
  @return the native form of this statement
}
function TZDBLibConnection.NativeSQL(const SQL: string): string;
begin
  Result := SQL;
end;

{**
  Sets this connection's auto-commit mode.
  If a connection is in auto-commit mode, then all its SQL
  statements will be executed and committed as individual
  transactions.  Otherwise, its SQL statements are grouped into
  transactions that are terminated by a call to either
  the method <code>commit</code> or the method <code>rollback</code>.
  By default, new connections are in auto-commit mode.

  The commit occurs when the statement completes or the next
  execute occurs, whichever comes first. In the case of
  statements returning a ResultSet, the statement completes when
  the last row of the ResultSet has been retrieved or the
  ResultSet has been closed. In advanced cases, a single
  statement may return multiple results as well as output
  parameter values. In these cases the commit occurs when all results and
  output parameter values have been retrieved.

  @param autoCommit true enables auto-commit; false disables auto-commit.
}
procedure TZDBLibConnection.SetAutoCommit(AutoCommit: Boolean);
begin
  if GetAutoCommit = AutoCommit then  Exit;
  if not Closed and AutoCommit then InternalExecuteStatement('commit');
  inherited;
  ReStartTransactionSupport;
end;

procedure TZDBLibConnection.InternalSetTransactionIsolation(Level: TZTransactIsolationLevel);
const
  IL: array[TZTransactIsolationLevel, 0..1] of string = (('READ COMMITTED', '1'), ('READ UNCOMMITTED', '0'), ('READ COMMITTED', '1'), ('REPEATABLE READ', '2'), ('SERIALIZABLE', '3'));
var
  Index: Integer;
  S: string;
begin
  Index := -1;
  if PlainDriver.GetProtocol = 'mssql' then Index := 0;
  if PlainDriver.GetProtocol = 'sybase' then Index := 1;

  S := 'SET TRANSACTION ISOLATION LEVEL ' + IL[GetTransactionIsolation, Index];
  InternalExecuteStatement(S);
end;

{**
  Attempts to change the transaction isolation level to the one given.
  The constants defined in the interface <code>Connection</code>
  are the possible transaction isolation levels.

  <P><B>Note:</B> This method cannot be called while
  in the middle of a transaction.

  @param level one of the TRANSACTION_* isolation values with the
    exception of TRANSACTION_NONE; some databases may not support other values
  @see DatabaseMetaData#supportsTransactionIsolationLevel
}
procedure TZDBLibConnection.SetTransactionIsolation(
  Level: TZTransactIsolationLevel);
begin
  if GetTransactionIsolation = Level then
    Exit;

  if not Closed and not AutoCommit and (GetTransactionIsolation <> tiNone) then
    InternalExecuteStatement('commit');

  inherited;

  if not Closed then
    InternalSetTransactionIsolation(Level);

  RestartTransactionSupport;
end;

{**
  Starts a new transaction. Used internally.
}
procedure TZDBLibConnection.StartTransaction;
begin
  InternalExecuteStatement('begin transaction');
end;

{**
  Makes all changes made since the previous
  commit/rollback permanent and releases any database locks
  currently held by the Connection. This method should be
  used only when auto-commit mode has been disabled.
  @see #setAutoCommit
}
procedure TZDBLibConnection.Commit;
begin
  if AutoCommit then
    raise Exception.Create(SCannotUseCommit);
  InternalExecuteStatement('commit');
  StartTransaction;
end;

{**
  Drops all changes made since the previous
  commit/rollback and releases any database locks currently held
  by this Connection. This method should be used only when auto-
  commit has been disabled.
  @see #setAutoCommit
}
procedure TZDBLibConnection.Rollback;
begin
  if AutoCommit then
    raise Exception.Create(SCannotUseRollBack);
  InternalExecuteStatement('rollback');
  StartTransaction;
end;

{**
  Releases a Connection's database and JDBC resources
  immediately instead of waiting for
  them to be automatically released.

  <P><B>Note:</B> A Connection is automatically closed when it is
  garbage collected. Certain fatal errors also result in a closed
  Connection.
}
procedure TZDBLibConnection.Close;
var
  LogMessage: string;
begin
  if Closed or (Not Assigned(PlainDriver) )then
    Exit;

  if not GetPlainDriver.dbDead(FHandle) then
    InternalExecuteStatement('if @@trancount > 0 rollback');

  LogMessage := Format('CLOSE CONNECTION TO "%s" DATABASE "%s"', [HostName, Database]);
  if GetPlainDriver.dbclose(FHandle) <> DBSUCCEED then
    CheckDBLibError(lcDisConnect, LogMessage);
  DriverManager.LogMessage(lcDisconnect, PlainDriver.GetProtocol, LogMessage);

  FHandle := nil;
  inherited;
end;

{**
  Puts this connection in read-only mode as a hint to enable
  database optimizations.

  <P><B>Note:</B> This method cannot be called while in the
  middle of a transaction.

  @param readOnly true enables read-only mode; false disables
    read-only mode.
}
procedure TZDBLibConnection.SetReadOnly(ReadOnly: Boolean);
begin
{ TODO -ofjanos -cAPI : I think it is not supported in this way }
  inherited;
end;

{**
  Sets a catalog name in order to select
  a subspace of this Connection's database in which to work.
  If the driver does not support catalogs, it will
  silently ignore this request.
}
procedure TZDBLibConnection.SetCatalog(const Catalog: string);
var
  LogMessage: string;
begin
  if (Catalog <> '') and not Closed then
  begin
    LogMessage := Format('SET CATALOG %s', [Catalog]);
    {$IFDEF DELPHI12_UP}
    if GetPLainDriver.dbUse(FHandle, PAnsiChar(UTF8String(Catalog))) <> DBSUCCEED then
    {$ELSE}
    if GetPLainDriver.dbUse(FHandle, PAnsiChar(Catalog)) <> DBSUCCEED then
    {$ENDIF}
      CheckDBLibError(lcOther, LogMessage);
    DriverManager.LogMessage(lcOther, PLainDriver.GetProtocol, LogMessage);
  end;
end;

{**
  Returns the Connection's current catalog name.
  @return the current catalog name or null
}
function TZDBLibConnection.GetCatalog: string;
begin
  Result := GetPlainDriver.dbName(FHandle);
  CheckDBLibError(lcOther, 'GETCATALOG');
end;

{**
  Returns the first warning reported by calls on this Connection.
  <P><B>Note:</B> Subsequent warnings will be chained to this
  SQLWarning.
  @return the first SQLWarning or null
}
function TZDBLibConnection.GetWarnings: EZSQLWarning;
begin
  Result := nil;
end;

{**
  Clears all warnings reported for this <code>Connection</code> object.
  After a call to this method, the method <code>getWarnings</code>
    returns null until a new warning is reported for this Connection.
}
procedure TZDBLibConnection.ClearWarnings;
begin
end;

initialization
  DBLibDriver := TZDBLibDriver.Create;
  DriverManager.RegisterDriver(DBLibDriver);
finalization
  if Assigned(DriverManager) then
    DriverManager.DeregisterDriver(DBLibDriver);
  DBLibDriver := nil;
end.
