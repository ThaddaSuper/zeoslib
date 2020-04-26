{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{         Interbase Database Connectivity Classes         }
{                                                         }
{        Originally written by Sergey Merkuriev           }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2012 Zeos Development Group       }
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
{   http://sourceforge.net/p/zeoslib/tickets/ (BUGTRACKER)}
{   svn://svn.code.sf.net/p/zeoslib/code-0/trunk (SVN)    }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZDbcInterbase6Statement;

interface

{$I ZDbc.inc}

{$IFNDEF ZEOS_DISABLE_INTERBASE} //if set we have an empty unit
uses Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils, Types, FmtBCD,
  {$IF defined (WITH_INLINE) and defined(MSWINDOWS) and not defined(WITH_UNICODEFROMLOCALECHARS)}Windows, {$IFEND}
  ZDbcIntfs, ZDbcStatement, ZDbcInterbase6, ZDbcInterbase6Utils, ZClasses,
  ZPlainFirebirdInterbaseConstants, ZPlainFirebirdDriver, ZCompatibility,
  ZDbcLogging, ZVariant, ZMessages, ZDbcCachedResultSet, ZDbcUtils;

type
  {** Implements Prepared SQL Statement for Interbase or FireBird. }
  TZInterbase6PreparedStatement = class;

  {** record for holding batch dml stmts }
  TZIBStmt = record
    Obj: TZInterbase6PreparedStatement;
    PreparedRowsOfArray: Integer;
  end;

  { TZAbstractInterbase6PreparedStatement }
  TZAbstractInterbase6PreparedStatement = class(TZRawParamDetectPreparedStatement)
  private
    FResultXSQLDA: IZSQLDA; //the out param or resultset Interface
    FIBConnection: IZInterbase6Connection; //the IB/FB connection interface
    FParamSQLData: IZParamsSQLDA;//the in param Interface
    FParamXSQLDA: PXSQLDA;
    FPlainDriver: TZInterbasePlainDriver; //the api holder object of the provider
    FCodePageArray: TWordDynArray; //an array of codepages
    FStatusVector: TARRAY_ISC_STATUS; //the errorcode vector
    FStmtHandle: TISC_STMT_HANDLE; //the smt handle
    FStatementType: TZIbSqlStatementType; //the stmt type
    FTypeTokens: TRawByteStringDynArray;
    FBatchStmts: array[Boolean] of TZIBStmt;
    FMaxRowsPerBatch, FMemPerRow: Integer;
    FDB_CP_ID: Integer;
    procedure ExecuteInternal;
    procedure ExceuteBatch;
    function SplittQuery(const SQL: SQLString): RawByteString;
  protected
    procedure CheckParameterIndex(var Value: Integer); override;
    procedure ReleaseConnection; override;
    function CreateResultSet: IZResultSet;
  public
    function GetRawEncodedSQL(const SQL: {$IF defined(FPC) and defined(WITH_RAWBYTESTRING)}RawByteString{$ELSE}String{$IFEND}): RawByteString; override;
  public
    constructor Create(const Connection: IZConnection; const SQL: string; Info: TStrings);
    procedure AfterClose; override;

    procedure Prepare; override;
    procedure Unprepare; override;

    function ExecuteQueryPrepared: IZResultSet; override;
    function ExecuteUpdatePrepared: Integer; override;
    function ExecutePrepared: Boolean; override;

    procedure ReleaseImmediat(const Sender: IImmediatelyReleasable;
      var AError: EZSQLConnectionLost); override;
  end;

  TZInterbase6PreparedStatement = class(TZAbstractInterbase6PreparedStatement, IZPreparedStatement)
  private
    procedure EncodePData(XSQLVAR: PXSQLVAR; Value: PAnsiChar; Len: LengthInt);
    procedure SetPAnsiChar(Index: Word; Value: PAnsiChar; Len: LengthInt);
    procedure SetPWideChar(Index: Word; Value: PWideChar; Len: LengthInt);
    procedure WriteLobBuffer(XSQLVAR: PXSQLVAR; Buffer: Pointer; Len: LengthInt);

    procedure InternalBindDouble(XSQLVAR: PXSQLVAR; const Value: Double);
  protected
    procedure PrepareInParameters; override;
    procedure UnPrepareInParameters; override;
    procedure AddParamLogValue(ParamIndex: Integer; SQLWriter: TZRawSQLStringWriter; Var Result: RawByteString); override;
  public //setters
    procedure RegisterParameter(ParameterIndex: Integer; SQLType: TZSQLType;
      ParamType: TZProcedureColumnType; const Name: String = ''; PrecisionOrSize: LengthInt = 0;
      Scale: LengthInt = 0); override;
    //a performance thing: direct dispatched methods for the interfaces :
    //https://stackoverflow.com/questions/36137977/are-interface-methods-always-virtual
    procedure SetNull(Index: Integer; {%H-}SQLType: TZSQLType);
    procedure SetBoolean(Index: Integer; Value: Boolean);
    procedure SetByte(Index: Integer; Value: Byte);
    procedure SetShort(Index: Integer; Value: ShortInt);
    procedure SetWord(Index: Integer; Value: Word);
    procedure SetSmall(Index: Integer; Value: SmallInt);
    procedure SetUInt(Index: Integer; Value: Cardinal);
    procedure SetInt(Index: Integer; Value: Integer);
    procedure SetULong(Index: Integer; const Value: UInt64);
    procedure SetLong(Index: Integer; const Value: Int64);
    procedure SetFloat(Index: Integer; Value: Single);
    procedure SetDouble(Index: Integer; const Value: Double);
    procedure SetCurrency(Index: Integer; const Value: Currency);
    procedure SetBigDecimal(Index: Integer; const Value: TBCD);

    procedure SetCharRec(Index: Integer; const Value: TZCharRec); reintroduce;
    procedure SetString(Index: Integer; const Value: String); reintroduce;
    {$IFNDEF NO_UTF8STRING}
    procedure SetUTF8String(Index: Integer; const Value: UTF8String); reintroduce;
    {$ENDIF}
    {$IFNDEF NO_ANSISTRING}
    procedure SetAnsiString(Index: Integer; const Value: AnsiString); reintroduce;
    {$ENDIF}
    procedure SetRawByteString(Index: Integer; const Value: RawByteString); reintroduce;
    procedure SetUnicodeString(Index: Integer; const Value: ZWideString); reintroduce;

    procedure SetDate(Index: Integer; const Value: TZDate); reintroduce; overload;
    procedure SetTime(Index: Integer; const Value: TZTime); reintroduce; overload;
    procedure SetTimestamp(Index: Integer; const Value: TZTimeStamp); reintroduce; overload;

    procedure SetBytes(Index: Integer; const Value: TBytes); reintroduce; overload;
    procedure SetBytes(ParameterIndex: Integer; Value: PByte; Len: NativeUInt); reintroduce; overload;
    procedure SetGUID(Index: Integer; const Value: TGUID); reintroduce;
    procedure SetBlob(Index: Integer; SQLType: TZSQLType; const Value: IZBlob); override{keep it virtual because of (set)ascii/uniocde/binary streams};
  end;

  TZInterbase6Statement = class(TZAbstractInterbase6PreparedStatement, IZStatement)
  public
    constructor Create(const Connection: IZConnection; Info: TStrings);
  end;

  TZInterbase6CallableStatement = class(TZAbstractCallableStatement_A, IZCallableStatement)
  protected
    function CreateExecutionStatement(const StoredProcName: String): TZAbstractPreparedStatement; override;
  end;

{$ENDIF ZEOS_DISABLE_INTERBASE} //if set we have an empty unit
implementation
{$IFNDEF ZEOS_DISABLE_INTERBASE} //if set we have an empty unit

uses Math, {$IFDEF WITH_UNITANSISTRINGS}AnsiStrings, {$ENDIF}
  ZSysUtils, ZFastCode, ZEncoding, ZDbcInterbase6ResultSet,
  ZDbcResultSet, ZTokenizer;

procedure BindSQLDAInParameters(BindList: TZBindList;
  Stmt: TZInterbase6PreparedStatement; ArrayOffSet, ArrayItersCount: Integer);
var
  I, J, ParamIndex: Integer;
  IsNull: Boolean;
  { array DML bindings }
  ZData: Pointer; //array entry
begin
  ParamIndex := FirstDbcIndex;
  for J := ArrayOffSet to ArrayOffSet+ArrayItersCount-1 do
    for i := 0 to BindList.Count -1 do
    begin
      IsNull := IsNullFromArray(BindList[i].Value, J);
      ZData := PZArray(BindList[i].Value).VArray;
      if (ZData = nil) or (IsNull) then
        Stmt.SetNull(ParamIndex, ZDbcIntfs.stUnknown)
      else
        case TZSQLType(PZArray(BindList[i].Value).VArrayType) of
          stBoolean: Stmt.SetBoolean(ParamIndex, TBooleanDynArray(ZData)[J]);
          stByte: Stmt.SetSmall(ParamIndex, TByteDynArray(ZData)[J]);
          stShort: Stmt.SetSmall(ParamIndex, TShortIntDynArray(ZData)[J]);
          stWord: Stmt.SetInt(ParamIndex, TWordDynArray(ZData)[J]);
          stSmall: Stmt.SetSmall(ParamIndex, TSmallIntDynArray(ZData)[J]);
          stLongWord: Stmt.SetLong(ParamIndex, TLongWordDynArray(ZData)[J]);
          stInteger: Stmt.SetInt(ParamIndex, TIntegerDynArray(ZData)[J]);
          stLong: Stmt.SetLong(ParamIndex, TInt64DynArray(ZData)[J]);
          stULong: Stmt.SetLong(ParamIndex, TUInt64DynArray(ZData)[J]);
          stFloat: Stmt.SetFloat(ParamIndex, TSingleDynArray(ZData)[J]);
          stDouble: Stmt.SetDouble(ParamIndex, TDoubleDynArray(ZData)[J]);
          stCurrency: Stmt.SetCurrency(ParamIndex, TCurrencyDynArray(ZData)[J]);
          stBigDecimal: Stmt.SetBigDecimal(ParamIndex, TBCDDynArray(ZData)[J]);
          stGUID: Stmt.SetGUID(ParamIndex, TGUIDDynArray(ZData)[j]);
          stString, stUnicodeString:
                case PZArray(BindList[i].Value).VArrayVariantType of
                  vtString: Stmt.SetString(ParamIndex, TStringDynArray(ZData)[j]);
                  {$IFNDEF NO_ANSISTRING}
                  vtAnsiString: Stmt.SetAnsiString(ParamIndex, TAnsiStringDynArray(ZData)[j]);
                  {$ENDIF}
                  {$IFNDEF NO_UTF8STRING}
                  vtUTF8String: Stmt.SetUTF8String(ParamIndex, TUTF8StringDynArray(ZData)[j]);
                  {$ENDIF}
                  vtRawByteString: Stmt.SetRawByteString(ParamIndex, TRawByteStringDynArray(ZData)[j]);
                  vtUnicodeString: Stmt.SetUnicodeString(ParamIndex, TUnicodeStringDynArray(ZData)[j]);
                  vtCharRec: Stmt.SetCharRec(ParamIndex, TZCharRecDynArray(ZData)[j]);
                  else
                    raise Exception.Create('Unsupported String Variant');
                end;
          stBytes:      Stmt.SetBytes(ParamIndex, TBytesDynArray(ZData)[j]);
          stDate:       if PZArray(BindList[i].Value).VArrayVariantType = vtDate
                        then Stmt.SetDate(ParamIndex, TZDateDynArray(ZData)[j])
                        else Stmt.SetDate(ParamIndex, TDateTimeDynArray(ZData)[j]);
          stTime:       if PZArray(BindList[i].Value).VArrayVariantType = vtTime
                        then Stmt.SetTime(ParamIndex, TZTimeDynArray(ZData)[j])
                        else Stmt.SetTime(ParamIndex, TDateTimeDynArray(ZData)[j]);
          stTimestamp:  if PZArray(BindList[i].Value).VArrayVariantType = vtTimeStamp
                        then Stmt.SetTimestamp(ParamIndex, TZTimeStampDynArray(ZData)[j])
                        else Stmt.SetTimestamp(ParamIndex, TDateTimeDynArray(ZData)[j]);
          stAsciiStream,
          stUnicodeStream,
          stBinaryStream: Stmt.SetBlob(ParamIndex, TZSQLType(PZArray(BindList[i].Value).VArrayType), TInterfaceDynArray(ZData)[j] as IZBlob);
          else
            raise EZIBConvertError.Create(SUnsupportedParameterType);
        end;
      Inc(ParamIndex);
    end;
end;

{ TZAbstractInterbase6PreparedStatement }

{**
  execute the dml batch array
}
procedure TZAbstractInterbase6PreparedStatement.ExceuteBatch;
var ArrayOffSet: Integer;
  procedure SplitQueryIntoPieces;
  var CurrentCS_ID: Integer;
  begin
    CurrentCS_ID := FDB_CP_ID;
    try
      FDB_CP_ID := CS_NONE;
      GetRawEncodedSQL(SQL);
    finally
      FDB_CP_ID := CurrentCS_ID;
    end;
  end;
begin
  //if not done already then split our query into pieces to build the
  //exceute block query
  if (FCachedQueryRaw = nil) then
    SplitQueryIntoPieces;
  Connection.StartTransaction;
  ArrayOffSet := 0;
  FIBConnection.GetTrHandle; //restart transaction if required
  try
    if (FBatchStmts[True].Obj <> nil) and (BatchDMLArrayCount >= FBatchStmts[True].PreparedRowsOfArray) then
      while (ArrayOffSet+FBatchStmts[True].PreparedRowsOfArray <= BatchDMLArrayCount) do begin
        BindSQLDAInParameters(BindList, FBatchStmts[True].Obj,
          ArrayOffSet, FBatchStmts[True].PreparedRowsOfArray);
        FBatchStmts[True].Obj.ExecuteInternal;
        Inc(ArrayOffSet, FBatchStmts[True].PreparedRowsOfArray);
      end;
    if (FBatchStmts[False].Obj <> nil) and (ArrayOffSet < BatchDMLArrayCount) then begin
      BindSQLDAInParameters(BindList, FBatchStmts[False].Obj,
        ArrayOffSet, FBatchStmts[False].PreparedRowsOfArray);
      FBatchStmts[False].Obj.ExecuteInternal;
    end;
    Connection.Commit;
  except
    Connection.Rollback;
    raise;
  end;
  LastUpdateCount := BatchDMLArrayCount;
end;

procedure TZAbstractInterbase6PreparedStatement.ExecuteInternal;
var iError: ISC_STATUS;
begin
  if BatchDMLArrayCount = 0 then
    With FIBConnection do begin
      if (FStatementType = stExecProc)
      then iError := FPlainDriver.isc_dsql_execute2(@FStatusVector, GetTrHandle,
        @FStmtHandle, GetDialect, FParamXSQLDA, FResultXSQLDA.GetData) //expecting out params
      else iError := FPlainDriver.isc_dsql_execute(@FStatusVector, GetTrHandle,
        @FStmtHandle, GetDialect, FParamXSQLDA); //not expecting a result
      if iError <> 0 then
        ZDbcInterbase6Utils.CheckInterbase6Error(FPlainDriver,
          FStatusVector, Self, lcExecute, ASQL);
      LastUpdateCount := GetAffectedRows(FPlainDriver, FStmtHandle, FStatementType, Self);
    end
  else ExceuteBatch;
end;

procedure TZAbstractInterbase6PreparedStatement.ReleaseConnection;
begin
  inherited ReleaseConnection;
  FIBConnection := nil;
end;

procedure TZAbstractInterbase6PreparedStatement.ReleaseImmediat(
  const Sender: IImmediatelyReleasable; var AError: EZSQLConnectionLost);
var B: boolean;
begin
  FStmtHandle := 0;
  for B := False to True do
    if Assigned(FBatchStmts[b].Obj) then
      FBatchStmts[b].Obj.ReleaseImmediat(Sender, AError);
  inherited ReleaseImmediat(Sender, AError);
end;

function TZAbstractInterbase6PreparedStatement.SplittQuery(const SQL: SQLString): RawByteString;
var
  I, ParamCnt, FirstComposePos: Integer;
  Tokens: TZTokenList;
  Token: PZToken;
  Tmp, Tmp2: RawByteString;
  ResultWriter, SectionWriter: TZRawSQLStringWriter;
  procedure Add(const Value: RawByteString; const Param: Boolean = False);
  begin
    SetLength(FCachedQueryRaw, Length(FCachedQueryRaw)+1);
    FCachedQueryRaw[High(FCachedQueryRaw)] := Value;
    SetLength(FIsParamIndex, Length(FCachedQueryRaw));
    IsParamIndex[High(FIsParamIndex)] := Param;
    ResultWriter.AddText(Value, Result);
  end;

begin
  ParamCnt := 0;
  Result := '';
  Tmp2 := '';
  Tmp := '';
  Tokens := Connection.GetDriver.GetTokenizer.TokenizeBufferToList(SQL, [toSkipEOF]);
  SectionWriter := TZRawSQLStringWriter.Create(Length(SQL) shr 5);
  ResultWriter := TZRawSQLStringWriter.Create(Length(SQL) shl 1);
  try
    FirstComposePos := 0;
    FTokenMatchIndex := -1;
    Token := nil;
    for I := 0 to Tokens.Count -1 do begin
      Token := Tokens[I];
      if Tokens.IsEqual(I, Char('?')) then begin
        if (FirstComposePos < I) then
          {$IFDEF UNICODE}
          SectionWriter.AddText(PUnicodeToRaw(Tokens[FirstComposePos].P, (Tokens[I-1].P-Tokens[FirstComposePos].P)+ Tokens[I-1].L, FClientCP), Tmp);
          {$ELSE}
          SectionWriter.AddText(Tokens[FirstComposePos].P, (Tokens[I-1].P-Tokens[FirstComposePos].P)+ Tokens[I-1].L, Tmp);
          {$ENDIF}
        SectionWriter.Finalize(Tmp);
        Add(Tmp, False);
        Tmp := '';
        {$IFDEF WITH_TBYTES_AS_RAWBYTESTRING}
        Add(ZUnicodeToRaw(Tokens.AsString(I, I), ConSettings^.ClientCodePage^.CP));
        {$ELSE}
        Add('?', True);
        {$ENDIF}
        Inc(ParamCnt);
        FirstComposePos := i +1;
      end
      {$IFNDEF UNICODE}
      else if ConSettings.AutoEncode or (FDB_CP_ID = CS_NONE) then
        case (Tokens[i].TokenType) of
          ttQuoted, ttComment,
          ttWord: begin
              if (FirstComposePos < I) then
                SectionWriter.AddText(Tokens[FirstComposePos].P, (Tokens[I-1].P-Tokens[FirstComposePos].P)+ Tokens[I-1].L, Tmp);
              if (FDB_CP_ID = CS_NONE) and ( //all identifiers collate unicode_fss if CS_NONE
                 (Token.TokenType = ttQuotedIdentifier) or
                 ((Token.TokenType = ttWord) and (Token.L > 1) and (Token.P^ = '"')))
              then Tmp2 := ZConvertStringToRawWithAutoEncode(Tokens.AsString(i), ConSettings^.CTRL_CP, zCP_UTF8)
              else Tmp2 := ConSettings^.ConvFuncs.ZStringToRaw(Tokens.AsString(i), ConSettings^.CTRL_CP, FClientCP);
              SectionWriter.AddText(Tmp2, Tmp);
              Tmp2 := '';
              FirstComposePos := I +1;
            end;
          else ;//satisfy FPC
        end
      {$ELSE}
      else if (FDB_CP_ID = CS_NONE) and (//all identifiers collate unicode_fss if CS_NONE
               (Token.TokenType = ttQuotedIdentifier) or
               ((Token.TokenType = ttWord) and (Token.L > 1) and (Token.P^ = '"'))) then begin
        if (FirstComposePos < I) then begin
          Tmp2 := PUnicodeToRaw(Tokens[FirstComposePos].P, (Tokens[I-1].P-Tokens[FirstComposePos].P)+ Tokens[I-1].L, FClientCP);
          SectionWriter.AddText(Tmp2, Tmp);
        end;
        Tmp2 := PUnicodeToRaw(Token.P, Token.L, zCP_UTF8);
        SectionWriter.AddText(Tmp2, Result);
        Tmp2 := EmptyRaw;
        FirstComposePos := I +1;
      end;
      {$ENDIF};
    end;
    if (FirstComposePos <= Tokens.Count-1) then begin
      {$IFDEF UNICODE}
      Tmp2 := PUnicodeToRaw(Tokens[FirstComposePos].P, (Token.P-Tokens[FirstComposePos].P)+ Token.L, FClientCP);
      SectionWriter.AddText(Tmp2, Tmp);
      Tmp2 := '';
      {$ELSE}
      SectionWriter.AddText(Tokens[FirstComposePos].P, (Token.P-Tokens[FirstComposePos].P)+ Token.L, Tmp);
      {$ENDIF}
    end;
    SectionWriter.Finalize(Tmp);
    if Tmp <> EmptyRaw then
      Add(Tmp, False);
    ResultWriter.Finalize(Result);
  finally
    Tokens.Free;
    FreeAndNil(SectionWriter);
    FreeAndNil(ResultWriter);
  end;
  SetBindCapacity(ParamCnt);
end;

{**
  Constructs this object and assignes the main properties.
  @param Connection a database connection object.
  @param Handle a connection handle pointer.
  @param Dialect a dialect Interbase SQL must be 1 or 2 or 3.
  @param Info a statement parameters.
}
constructor TZAbstractInterbase6PreparedStatement.Create(const Connection: IZConnection;
  const SQL: string; Info: TStrings);
begin
  inherited Create(Connection, SQL, Info);
  FIBConnection := Connection as IZInterbase6Connection;
  FPlainDriver := TZInterbasePlainDriver(FIBConnection.GetIZPlainDriver.GetInstance);
  FCodePageArray := FPlainDriver.GetCodePageArray;
  FDB_CP_ID := ConSettings^.ClientCodePage^.ID;
  FCodePageArray[FDB_CP_ID] := ConSettings^.ClientCodePage^.CP; //reset the cp if user wants to wite another encoding e.g. 'NONE' or DOS852 vc WIN1250
  ResultSetType := rtForwardOnly;
  FStmtHandle := 0;
  FMaxRowsPerBatch := 0;
end;

function TZAbstractInterbase6PreparedStatement.CreateResultSet: IZResultSet;
var
  NativeResultSet: TZInterbase6XSQLDAResultSet;
  CachedResolver: TZInterbase6CachedResolver;
  CachedResultSet: TZInterbaseCachedResultSet;
begin
  if FOpenResultSet <> nil then
    Result := IZResultSet(FOpenResultSet)
  else begin
    NativeResultSet := TZInterbase6XSQLDAResultSet.Create(Self, SQL, @FStmtHandle,
      FResultXSQLDA, CachedLob, FStatementType);
    if (GetResultSetConcurrency = rcUpdatable) or (GetResultSetType <> rtForwardOnly) then begin
      if FIBConnection.IsFirebirdLib and (FIBConnection.GetHostVersion >= 2000000) //is the SQL2003 st. IS DISTINCT FROM supported?
      then CachedResolver  := TZCachedResolverFirebird2up.Create(Self, NativeResultSet.GetMetadata)
      else CachedResolver  := TZInterbase6CachedResolver.Create(Self, NativeResultSet.GetMetadata);
      CachedResultSet := TZInterbaseCachedResultSet.Create(NativeResultSet, SQL, CachedResolver, ConSettings);
      CachedResultSet.SetConcurrency(GetResultSetConcurrency);
      Result := CachedResultSet;
    end else
      Result := NativeResultSet;
    NativeResultSet.TransactionResultSet := Pointer(Result);
    FOpenResultSet := Pointer(Result);
  end;
end;

procedure TZAbstractInterbase6PreparedStatement.CheckParameterIndex(
  var Value: Integer);
var I: Integer;
begin
  if not Prepared then
    Prepare;
  if (Value<0) or (Value+1 > BindList.Count) then
    raise EZSQLException.Create(SInvalidInputParameterCount);
  if BindList.HasOutOrInOutOrResultParam then
    for I := 0 to Value do
      if Ord(BindList[I].ParamType) > Ord(pctInOut) then
        Dec(Value);
end;

procedure TZAbstractInterbase6PreparedStatement.AfterClose;
begin
  if (FStmtHandle <> 0) then begin// Free statement-handle! Otherwise: Exception!
    if FPlainDriver.isc_dsql_free_statement(@FStatusVector, @FStmtHandle, DSQL_drop) <> 0 then
      CheckInterbase6Error(FPlainDriver,
          FStatusVector, Self, lcOther, 'isc_dsql_free_statement');
    FStmtHandle := 0;
  end;
end;

procedure TZAbstractInterbase6PreparedStatement.Prepare;
var
  eBlock: RawByteString;
  PreparedRowsOfArray: Integer;
  TypeItem: AnsiChar;
  Buffer: array[0..7] of AnsiChar;
  FinalChunkSize: Integer;
  L: LengthInt;
label jmpEB;

  procedure PrepareArrayStmt(var Slot: TZIBStmt);
  begin
    if (Slot.Obj = nil) or (Slot.PreparedRowsOfArray <> PreparedRowsOfArray) then begin
      if Slot.Obj <> nil then begin
        Slot.Obj.BindList.Count := 0;
        {$IFNDEF AUTOREFCOUNT}
        Slot.Obj._Release;
        {$ENDIF}
        Slot.Obj := nil;
      end;
      Slot.Obj := TZInterbase6PreparedStatement.Create(Connection, '', Info);
      {$IFNDEF AUTOREFCOUNT}
      Slot.Obj._AddRef;
      {$ENDIF}
      Slot.Obj.FASQL := eBlock;
      Slot.Obj.BindList.Count := BindList.Count*PreparedRowsOfArray;
      Slot.PreparedRowsOfArray := PreparedRowsOfArray;
      Slot.Obj.Prepare;
    end;
  end;
  procedure PrepareFinalChunk(Rows: Integer);
  begin
    eBlock := GetExecuteBlockString(FParamSQLData,
      IsParamIndex, BindList.Count, Rows, FCachedQueryRaw,
      FPlainDriver, FMemPerRow, PreparedRowsOfArray, FMaxRowsPerBatch,
      FTypeTokens, FStatementType, FIBConnection.GetXSQLDAMaxSize);
    PrepareArrayStmt(FBatchStmts[False]);
  end;
begin
  if (not Prepared) then begin
    with FIBConnection do begin
    { Allocate an sql statement }
    if FStmtHandle = 0 then
      if FPlainDriver.isc_dsql_allocate_statement(@FStatusVector, GetDBHandle, @FStmtHandle) <> 0 then
        CheckInterbase6Error(FPlainDriver, FStatusVector, Self, lcOther, ASQL);
      { Prepare an sql statement }
      //get overlong string running:
      //see request https://zeoslib.sourceforge.io/viewtopic.php?f=40&p=147689#p147689
      //http://tracker.firebirdsql.org/browse/CORE-1117?focusedCommentId=31493&page=com.atlassian.jira.plugin.system.issuetabpanels%3Acomment-tabpanel#action_31493
      L := Length(ASQL);
      if L > High(Word) then //test word range overflow
        L := 0; //fall back to C-String behavior
      if FPlainDriver.isc_dsql_prepare(@FStatusVector, GetTrHandle, @FStmtHandle,
          Word(L), Pointer(ASQL), GetDialect, nil) <> 0 then
        CheckInterbase6Error(FPlainDriver, FStatusVector, Self, lcPrepStmt, ASQL); //Check for disconnect AVZ
      { Set Statement Type }
      TypeItem := AnsiChar(isc_info_sql_stmt_type);

      { Get information about a prepared DSQL statement. }
      if FPlainDriver.isc_dsql_sql_info(@FStatusVector, @FStmtHandle, 1,
          @TypeItem, SizeOf(Buffer), @Buffer[0]) <> 0 then
        CheckInterbase6Error(FPlainDriver, FStatusVector, Self);

      if Buffer[0] = AnsiChar(isc_info_sql_stmt_type)
      then FStatementType := TZIbSqlStatementType(ReadInterbase6Number(FPlainDriver, Buffer[1]))
      else FStatementType := stUnknown;

      if FStatementType in [stUnknown, stGetSegment, stPutSegment, stStartTrans, stCommit, stRollback] then begin
        FPlainDriver.isc_dsql_free_statement(@FStatusVector, @FStmtHandle, DSQL_CLOSE);
        raise EZSQLException.Create(SStatementIsNotAllowed);
      end else if FStatementType in [stSelect, stExecProc, stSelectForUpdate] then begin
        FResultXSQLDA := TZSQLDA.Create(Connection, ConSettings);
        { Initialise ouput param and fields }
        if FPlainDriver.isc_dsql_describe(@FStatusVector, @FStmtHandle, GetDialect, FResultXSQLDA.GetData) <> 0 then
          CheckInterbase6Error(FPlainDriver, FStatusVector, Self, lcExecute, ASQL);
        if FResultXSQLDA.GetData^.sqld <> FResultXSQLDA.GetData^.sqln then begin
          FResultXSQLDA.AllocateSQLDA;
          if FPlainDriver.isc_dsql_describe(@FStatusVector, @FStmtHandle, GetDialect, FResultXSQLDA.GetData) <> 0 then
            CheckInterbase6Error(FPlainDriver, FStatusVector, Self, lcExecute, ASql);
        end;
        FResultXSQLDA.InitFields(False);
      end;
    end;
    inherited Prepare; //log action and prepare params
  end;
  if BatchDMLArrayCount > 0 then begin
    if FMaxRowsPerBatch = 0 then begin //init to find out max rows per batch
jmpEB:eBlock := GetExecuteBlockString(FParamSQLData,
        IsParamIndex, BindList.Count, BatchDMLArrayCount, FCachedQueryRaw,
        FPlainDriver, FMemPerRow, PreparedRowsOfArray, FMaxRowsPerBatch,
          FTypeTokens, FStatementType, FIBConnection.GetXSQLDAMaxSize);
    end else
      eBlock := '';
    FinalChunkSize := (BatchDMLArrayCount mod FMaxRowsPerBatch);
    if (FMaxRowsPerBatch <= BatchDMLArrayCount) and (FBatchStmts[True].Obj = nil) then begin
      if eBlock = '' then goto jmpEB;
      PrepareArrayStmt(FBatchStmts[True]); //max block size per batch
    end;
    if (FinalChunkSize > 0) and ((FBatchStmts[False].Obj = nil) or
       (FinalChunkSize <> FBatchStmts[False].PreparedRowsOfArray)) then //if final chunk then
      PrepareFinalChunk(FinalChunkSize);
  end;
end;

{**
  unprepares the statement, deallocates all bindings and handles
}
procedure TZAbstractInterbase6PreparedStatement.Unprepare;
var b: Boolean;
begin
  for b := False to True do
    if FBatchStmts[b].Obj <> nil then begin
      FBatchStmts[b].Obj.BindList.Count := 0;
      {$IFNDEF AUTOREFCOUNT}
      FBatchStmts[b].Obj._Release;
      {$ENDIF}
      FBatchStmts[b].Obj := nil;
    end;
  FMaxRowsPerBatch := 0;
  FResultXSQLDA := nil;
  FParamSQLData := nil;
  SetLength(FTypeTokens, 0);
  inherited Unprepare;
  if (FStmtHandle <> 0) then //check if prepare did fail. otherwise we unprepare the handle
    if FPlainDriver.isc_dsql_free_statement(@fStatusVector, @FStmtHandle, DSQL_UNPREPARE) <> 0 then
      CheckInterbase6Error(FPlainDriver, FStatusVector, Self, lcOther, 'isc_dsql_free_statement');
end;

{**
  Executes any kind of SQL statement.
  Some prepared statements return multiple results; the <code>execute</code>
  method handles these complex statements as well as the simpler
  form of statements handled by the methods <code>executeQuery</code>
  and <code>executeUpdate</code>.
  @see Statement#execute
}
function TZAbstractInterbase6PreparedStatement.ExecutePrepared: Boolean;
begin
  Prepare;
  PrepareLastResultSetForReUse;
  if DriverManager.HasLoggingListener then
    DriverManager.LogMessage(lcBindPrepStmt,Self);
  ExecuteInternal;
  { Create ResultSet if possible else free Statement Handle }
  if (FStatementType in [stSelect, stExecProc, stSelectForUpdate]) and (FResultXSQLDA.GetFieldCount <> 0) then begin
    if not Assigned(LastResultSet) then
      LastResultSet := CreateResultSet;
    if (FStatementType = stExecProc) or BindList.HasOutOrInOutOrResultParam then
      FOutParamResultSet := LastResultSet;
  end else
    LastResultSet := nil;
  Result := LastResultSet <> nil;
  inherited ExecutePrepared;
end;

{**
  Executes the SQL query in this <code>PreparedStatement</code> object
  and returns the result set generated by the query.

  @return a <code>ResultSet</code> object that contains the data produced by the
    query; never <code>null</code>
}
function TZAbstractInterbase6PreparedStatement.ExecuteQueryPrepared: IZResultSet;
begin
  Prepare;
  PrepareOpenResultSetForReUse;
  if DriverManager.HasLoggingListener then
    DriverManager.LogMessage(lcBindPrepStmt,Self);
  ExecuteInternal;

  if (FResultXSQLDA <> nil) and (FResultXSQLDA.GetFieldCount <> 0) then begin
    if (FStatementType = stSelect) and Assigned(FOpenResultSet) and not BindList.HasOutOrInOutOrResultParam
    then Result := IZResultSet(FOpenResultSet)
    else Result := CreateResultSet;
    if (FStatementType = stExecProc) or BindList.HasOutOrInOutOrResultParam then
      FOutParamResultSet := Result;
  end else begin
    Result := nil;
    raise EZSQLException.Create(SCanNotRetrieveResultSetData);
  end;

  inherited ExecuteQueryPrepared;
end;

{**
  Executes the SQL INSERT, UPDATE or DELETE statement
  in this <code>PreparedStatement</code> object.
  In addition,
  SQL statements that return nothing, such as SQL DDL statements,
  can be executed.

  @return either the row count for INSERT, UPDATE or DELETE statements;
  or 0 for SQL statements that return nothing
}
function TZAbstractInterbase6PreparedStatement.ExecuteUpdatePrepared: Integer;
begin
  Prepare;
  LastResultSet := nil;
  PrepareOpenResultSetForReUse;
  if DriverManager.HasLoggingListener then
    DriverManager.LogMessage(lcBindPrepStmt,Self);
  ExecuteInternal;
  Result := LastUpdateCount;
  if BatchDMLArrayCount = 0 then
    case FStatementType of
      stCommit, stRollback, stUnknown: Result := -1;
      stSelect: if BindList.HasOutParam then begin
          FOutParamResultSet := CreateResultSet;
          FOpenResultSet := nil;
        end else if FResultXSQLDA.GetFieldCount <> 0 then
          if FPlainDriver.isc_dsql_free_statement(@FStatusVector, @FStmtHandle, DSQL_CLOSE) <> 0 then
            CheckInterbase6Error(FPlainDriver, FStatusVector, Self, lcOther, 'isc_dsql_free_statement');
      stExecProc: { Create ResultSet if possible }
        if FResultXSQLDA.GetFieldCount <> 0 then
          FOutParamResultSet := CreateResultSet;
    end;
  inherited ExecuteUpdatePrepared;
end;

function TZAbstractInterbase6PreparedStatement.GetRawEncodedSQL(
  const SQL: {$IF defined(FPC) and defined(WITH_RAWBYTESTRING)}RawByteString{$ELSE}String{$IFEND}): RawByteString;
begin
  if (BatchDMLArrayCount > 0) or ConSettings^.AutoEncode or (FDB_CP_ID = CS_NONE)
  then Result := SplittQuery(SQL)
  else Result := ConSettings^.ConvFuncs.ZStringToRaw(SQL, ConSettings^.CTRL_CP, ConSettings^.ClientCodePage^.CP);
end;

procedure TZInterbase6PreparedStatement.EncodePData(XSQLVAR: PXSQLVAR;
  Value: PAnsiChar; Len: LengthInt);
begin
  if Len > XSQLVAR.sqllen then begin
    FreeMem(XSQLVAR.sqldata, XSQLVAR.sqllen+SizeOf(Short));
    XSQLVAR.sqllen := ((((Len-1) shr 3)+1) shl 3);
    GetMem(XSQLVAR.sqldata, XSQLVAR.sqllen+SizeOf(Short));
  end;
  PISC_VARYING(XSQLVAR.sqldata).strlen := Len;
  {$IFDEF FAST_MOVE}ZFastCode{$ELSE}System{$ENDIF}.Move(Value^, PISC_VARYING(XSQLVAR.sqldata).str[0], Len);
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;

procedure TZInterbase6PreparedStatement.InternalBindDouble(XSQLVAR: PXSQLVAR;
  const Value: Double);
var TimeStamp: TZTimeStamp;
begin
  case (XSQLVAR.sqltype and not(1)) of
    SQL_FLOAT     : PSingle(XSQLVAR.sqldata)^   := Value;
    SQL_D_FLOAT,
    SQL_DOUBLE    : PDouble(XSQLVAR.sqldata)^   := Value;
    SQL_LONG      : if XSQLVAR.sqlscale = 0
                    then PISC_LONG(XSQLVAR.sqldata)^ := Round(Value)
                    else PISC_LONG(XSQLVAR.sqldata)^ := Round(Value*IBScaleDivisor[XSQLVAR.sqlscale]);
    SQL_BOOLEAN   : PISC_BOOLEAN(XSQLVAR.sqldata)^ := Ord(Value <> 0);
    SQL_BOOLEAN_FB: PISC_BOOLEAN_FB(XSQLVAR.sqldata)^ := Ord(Value <> 0);
    SQL_SHORT     : if XSQLVAR.sqlscale = 0
                    then PISC_SHORT(XSQLVAR.sqldata)^ := Round(Value)
                    else PISC_SHORT(XSQLVAR.sqldata)^ := Round(Value*IBScaleDivisor[XSQLVAR.sqlscale]);
    SQL_INT64,
    SQL_QUAD      : if XSQLVAR.sqlscale = 0
                    then PISC_INT64(XSQLVAR.sqldata)^ := Round(Value)
                    else PISC_INT64(XSQLVAR.sqldata)^ := Round(Value*IBScaleDivisor[XSQLVAR.sqlscale]);
    SQL_TYPE_DATE : begin
                      DecodeDate(Value, TimeStamp.Year, TimeStamp.Month, TimeStamp.Day);
                      isc_encode_date(PISC_DATE(XSQLVAR.sqldata)^, TimeStamp.Year, TimeStamp.Month, TimeStamp.Day);
                    end;
    SQL_TYPE_TIME : begin
                      DecodeTime(Value, TimeStamp.Hour, TimeStamp.Minute, TimeStamp.Second, PWord(@TimeStamp.Fractions)^);
                      TimeStamp.Fractions := PWord(@TimeStamp.Fractions)^*10;
                      isc_encode_time(PISC_TIME(XSQLVAR.sqldata)^, TimeStamp.Hour, TimeStamp.Minute, TimeStamp.Second, TimeStamp.Fractions);
                    end;
    SQL_TIMESTAMP : begin
                      DecodeDate(Value, TimeStamp.Year, TimeStamp.Month, TimeStamp.Day);
                      isc_encode_date(PISC_TIMESTAMP(XSQLVAR.sqldata).timestamp_date, TimeStamp.Year, TimeStamp.Month, TimeStamp.Day);
                      DecodeTime(Value, TimeStamp.Hour, TimeStamp.Minute, TimeStamp.Second, PWord(@TimeStamp.Fractions)^);
                      TimeStamp.Fractions := PWord(@TimeStamp.Fractions)^*10;
                      isc_encode_time(PISC_TIMESTAMP(XSQLVAR.sqldata).timestamp_time, TimeStamp.Hour, TimeStamp.Minute, TimeStamp.Second, TimeStamp.Fractions);
                    end;
    else raise EZIBConvertError.Create(SUnsupportedDataType);
  end;
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;

{**
  Prepares eventual structures for binding input parameters.
}
procedure TZInterbase6PreparedStatement.PrepareInParameters;
var
  StatusVector: TARRAY_ISC_STATUS;
begin
  With FIBConnection do begin
    {create the parameter bind structure}
    FParamSQLData := TZParamsSQLDA.Create(Connection, ConSettings);
    FParamXSQLDA := FParamSQLData.GetData;
    if FParamXSQLDA.sqln < BindList.Capacity then begin
      FParamXSQLDA.sqld := BindList.Capacity;
      FParamXSQLDA := FParamSQLData.AllocateSQLDA;
    end;
    {check dynamic sql}
    if FPlainDriver.isc_dsql_describe_bind(@StatusVector, @FStmtHandle, GetDialect, FParamXSQLDA) <> 0 then
      ZDbcInterbase6Utils.CheckInterbase6Error(FPlainDriver, StatusVector, Self, lcExecute, ASQL);

    //alloc space for lobs, arrays, param-types
    if ((FStatementType = stExecProc) and (FResultXSQLDA.GetFieldCount > 0)) or
       ((FStatementType = stSelect) and (BindList.HasOutOrInOutOrResultParam))
    then SetParamCount(FParamXSQLDA^.sqld + FResultXSQLDA.GetFieldCount)
    else SetParamCount(FParamXSQLDA^.sqld);

    { Resize XSQLDA structure if required }
    if FParamXSQLDA^.sqld <> FParamXSQLDA^.sqln then begin
      FParamXSQLDA := FParamSQLData.AllocateSQLDA;
      if FPlainDriver.isc_dsql_describe_bind(@StatusVector, @FStmtHandle, GetDialect,FParamXSQLDA) <> 0 then
        ZDbcInterbase6Utils.CheckInterbase6Error(FPlainDriver, StatusVector, Self, lcExecute, ASQL);
    end;
    FParamSQLData.InitFields(True);
  end;

end;

procedure TZInterbase6PreparedStatement.RegisterParameter(
  ParameterIndex: Integer; SQLType: TZSQLType; ParamType: TZProcedureColumnType;
  const Name: String; PrecisionOrSize, Scale: LengthInt);
begin
  if ParamType = pctResultSet then
    Raise EZUnsupportedException.Create(SUnsupportedOperation);
  inherited;
end;

{**
  Sets the designated parameter to a Java <code>AnsiString</code> value.
  The driver converts this
  to an SQL <code>VARCHAR</code> or <code>LONGVARCHAR</code> value
  (depending on the argument's
  size relative to the driver's limits on <code>VARCHAR</code> values)
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
{$IFNDEF NO_ANSISTRING}
procedure TZInterbase6PreparedStatement.SetAnsiString(Index: Integer;
  const Value: AnsiString);
var XSQLVAR: PXSQLVAR;
 CS_ID: ISC_SHORT;
 L: LengthInt;
 P: PAnsiChar;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  if Value <> '' then begin
    L := Length(Value);
    P := Pointer(Value);
    case (XSQLVAR.sqltype and not(1)) of
      SQL_TEXT,
      SQL_VARYING   : begin
                      CS_ID := XSQLVAR.sqlsubtype and 255;
                      if (CS_ID = CS_BINARY) or (FCodePageArray[CS_ID] = ZOSCodePage) then
                        EncodePData(XSQLVAR, P, L)
                      else begin
                        PRawToRawConvert(P, L, ZOSCodePage, FCodePageArray[CS_ID], FRawTemp);
                        L := Length(FRawTemp);
                        P := Pointer(FRawTemp);
                        EncodePData(XSQLVAR, P, L);
                      end;
                    end;
      SQL_BLOB,
      SQL_QUAD      : if XSQLVAR.sqlsubtype = isc_blob_text then
                        if (ClientCP = ZOSCodePage) then
                          WriteLobBuffer(XSQLVAR, P, L)
                        else begin
                          PRawToRawConvert(P, L, ZOSCodePage, FClientCP, FRawTemp);
                          L := Length(FRawTemp);
                          P := Pointer(FRawTemp);
                          WriteLobBuffer(XSQLVAR, P, L)
                        end
                      else WriteLobBuffer(XSQLVAR, P, L);
      else SetPAnsiChar(Index, P, L);
    end;
  end else
    SetPAnsiChar(Index, PEmptyAnsiString, 0)
end;
{$ENDIF}

{**
  Sets the designated parameter to a <code>java.math.BigDecimal</code> value.
  The driver converts this to an SQL <code>NUMERIC</code> value when
  it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetBigDecimal(
  Index: Integer; const Value: TBCD);
var XSQLVAR: PXSQLVAR;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  case (XSQLVAR.sqltype and not(1)) of
    SQL_LONG      : BCD2ScaledOrdinal(Value, XSQLVAR.sqldata, SizeOf(ISC_LONG), -XSQLVAR.sqlscale);
    SQL_SHORT     : BCD2ScaledOrdinal(Value, XSQLVAR.sqldata, SizeOf(ISC_SHORT), -XSQLVAR.sqlscale);
    SQL_INT64,
    SQL_QUAD      : BCD2ScaledOrdinal(Value, XSQLVAR.sqldata, SizeOf(ISC_INT64), -XSQLVAR.sqlscale);
    SQL_TEXT,
    SQL_VARYING   : begin
                      EncodePData(XSQLVAR, @fABuffer[0], BcdToRaw(Value, @fABuffer[0], '.'));
                      Exit;
                    end;
    else SetDouble(Index{$IFNDEF GENERIC_INDEX}+1{$ENDIF}, BCDToDouble(Value));
  end;
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;

procedure TZInterbase6PreparedStatement.SetBlob(Index: Integer;
  SQLType: TZSQLType; const Value: IZBlob);
var
  XSQLVAR: PXSQLVAR;
  P: PAnsiChar;
  L: NativeUint;
  IBLob: IZInterbaseLob;
  ibsqltype: ISC_SHORT;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  SQLType := FParamSQLData.GetFieldSqlType(Index);
  ibsqltype := XSQLVAR.sqltype and not(1);
  if (Value = nil) or Value.IsEmpty then begin
    BindList.SetNull(Index, SQLType);
    P := nil;
    L := 0;//satisfy compiler
    //if (XSQLVAR.sqlind = nil) then //ntNullable -> Exception?
  end else if Supports(Value, IZInterbaseLob, IBLob) and ((ibsqltype = SQL_QUAD) or (ibsqltype = SQL_BLOB)) then begin
    PISC_QUAD(XSQLVAR.sqldata)^ := IBLob.GetBlobId;
    if (XSQLVAR.sqlind <> nil) then
      XSQLVAR.sqlind^ := ISC_NOTNULL;
    Exit;
  end else begin
    BindList.Put(Index, SQLType, Value); //localize for the refcount
    if (Value <> nil) and (SQLType in [stAsciiStream, stUnicodeStream]) then
      if Value.IsClob then begin
        Value.SetCodePageTo(ConSettings^.ClientCodePage.CP);
        P := Value.GetPAnsiChar(ConSettings^.ClientCodePage.CP, FRawTemp, L)
      end else begin
        BindList.Put(Index, stAsciiStream, CreateRawCLobFromBlob(Value, ConSettings, FOpenLobStreams));
        P := IZCLob(BindList[Index].Value).GetPAnsiChar(ConSettings^.ClientCodePage.CP, FRawTemp, L);
      end
    else
      P := Value.GetBuffer(FRawTemp, L);
  end;
  if P <> nil then begin
    case ibsqltype of
      SQL_TEXT,
      SQL_VARYING   : EncodePData(XSQLVAR, P, L);
      SQL_BLOB,
      SQL_QUAD      : WriteLobBuffer(XSQLVAR, P, L);
      else raise EZIBConvertError.Create(SUnsupportedDataType);
    end;
  end else if (XSQLVAR.sqlind <> nil) then
    XSQLVAR.sqlind^ := ISC_NULL;

end;

{**
  Sets the designated parameter to a Java <code>boolean</code> value.
  The driver converts this
  to an SQL <code>BIT</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetBoolean(
  Index: Integer; Value: Boolean);
var XSQLVAR: PXSQLVAR;
begin
  {$IFNDEF GENERIC_INDEX}Dec(Index);{$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  case (XSQLVAR.sqltype and not(1)) of
    SQL_FLOAT     : PSingle(XSQLVAR.sqldata)^   := Ord(Value);
    SQL_D_FLOAT,
    SQL_DOUBLE    : PDouble(XSQLVAR.sqldata)^   := Ord(Value);
    SQL_LONG      : if Value
                    then PISC_LONG(XSQLVAR.sqldata)^ := IBScaleDivisor[XSQLVAR.sqlscale]
                    else PISC_LONG(XSQLVAR.sqldata)^ := 0;
    SQL_BOOLEAN   : PISC_BOOLEAN(XSQLVAR.sqldata)^ := Ord(Value);
    SQL_BOOLEAN_FB: PISC_BOOLEAN_FB(XSQLVAR.sqldata)^ := Ord(Value);
    SQL_SHORT     : if Value
                    then PISC_SHORT(XSQLVAR.sqldata)^ := IBScaleDivisor[XSQLVAR.sqlscale]
                    else PISC_SHORT(XSQLVAR.sqldata)^ := 0;
    SQL_INT64,
    SQL_QUAD      : if Value
                    then PISC_INT64(XSQLVAR.sqldata)^ := IBScaleDivisor[XSQLVAR.sqlscale]
                    else PISC_INT64(XSQLVAR.sqldata)^ := 0;
    SQL_TEXT,
    SQL_VARYING   : begin
                      PByte(@fABuffer[0])^ := Ord('0')+Ord(Value);
                      EncodePData(XSQLVAR, @fABuffer[0], 1);
                      Exit;
                    end;
    else raise EZIBConvertError.Create(SUnsupportedDataType);
  end;
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;

{**
  Sets the designated parameter to a Java <code>byte</code> value.
  The driver converts this
  to an SQL <code>Byte</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetByte(Index: Integer;
  Value: Byte);
begin
  SetSmall(Index, Value);
end;

{**
  Sets the designated parameter to a Java array of bytes by reference.
  The driver converts this to an SQL <code>VARBINARY</code> or
  <code>LONGVARBINARY</code> (depending on the argument's size relative to
  the driver's limits on
  <code>VARBINARY</code> values) when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param Value the parameter value address
  @param Len the length of the addressed value
}
procedure TZInterbase6PreparedStatement.SetBytes(ParameterIndex: Integer;
  Value: PByte; Len: NativeUInt);
var XSQLVAR: PXSQLVAR;
begin
  {$IFNDEF GENERIC_INDEX}
  ParameterIndex := ParameterIndex -1;
  {$ENDIF}
  CheckParameterIndex(ParameterIndex);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[ParameterIndex];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  case (XSQLVAR.sqltype and not(1)) of
    SQL_TEXT,
    SQL_VARYING   : EncodePData(XSQLVAR, PAnsiChar(Value), Len);
    SQL_BLOB,
    SQL_QUAD      : WriteLobBuffer(XSQLVAR, Value, Len);
    else raise EZIBConvertError.Create(SUnsupportedDataType);
  end;
end;

{**
  Sets the designated parameter to a Java array of bytes.  The driver converts
  this to an SQL <code>VARBINARY</code> or <code>LONGVARBINARY</code>
  (depending on the argument's size relative to the driver's limits on
  <code>VARBINARY</code> values) when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetBytes(Index: Integer;
  const Value: TBytes);
var XSQLVAR: PXSQLVAR;
  L: LengthInt;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  L := Length(Value);
  case (XSQLVAR.sqltype and not(1)) of
    SQL_TEXT,
    SQL_VARYING   : EncodePData(XSQLVAR, Pointer(Value), L);
    SQL_BLOB,
    SQL_QUAD      : WriteLobBuffer(XSQLVAR, Pointer(Value), L);
    else raise EZIBConvertError.Create(SUnsupportedDataType);
  end;
end;

{**
  Sets the designated parameter to a Java <code>TZCharRec</code> value.
  The driver converts this
  to an SQL <code>VARCHAR</code> or <code>LONGVARCHAR</code> value
  (depending on the argument's
  size relative to the driver's limits on <code>VARCHAR</code> values)
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetCharRec(Index: Integer;
  const Value: TZCharRec);
var XSQLVAR: PXSQLVAR;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if Value.CP = zCP_UTF16 then
    SetPWideChar(Index, Value.P, Value.Len)
  else begin
    {$R-}
    XSQLVAR := @FParamXSQLDA.sqlvar[Index];
    {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    if (Value.CP = ClientCP) or (XSQLVAR.sqltype and not(1) = CS_BINARY) or
      ((FDB_CP_ID = CS_NONE) and
      ((XSQLVAR.sqltype and not(1) = SQL_TEXT) or (XSQLVAR.sqltype and not(1) = SQL_VARYING)) and
      (FCodePageArray[XSQLVAR.sqlsubtype and 255] = Value.CP))
    then SetPAnsiChar(Index, Value.P, Value.Len)
    else begin
      FUniTemp := PRawToUnicode(Value.P, Value.Len, Value.CP); //localize it
      if FUniTemp <> ''
      then SetPWideChar(Index, Pointer(FUniTemp), Length(FUniTemp))
      else SetPWideChar(Index, PEmptyUnicodeString, 0);
    end;
  end;
end;

{**
  Sets the designated parameter to a Java <code>currency</code> value.
  The driver converts this
  to an SQL <code>CURRENCY</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetCurrency(Index: Integer;
  const Value: Currency);
var XSQLVAR: PXSQLVAR;
  i64: Int64 absolute Value;
  P: PAnsiChar;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  case (XSQLVAR.sqltype and not(1)) of
    SQL_FLOAT     : PSingle(XSQLVAR.sqldata)^   := Value;
    SQL_D_FLOAT,
    SQL_DOUBLE    : PDouble(XSQLVAR.sqldata)^   := Value;
    SQL_LONG      : if XSQLVAR.sqlscale = -4 then  //scale fits!
                      PISC_LONG(XSQLVAR.sqldata)^ := I64
                    else if XSQLVAR.sqlscale > -4 then //EH: check the modulo?
                      PISC_LONG(XSQLVAR.sqldata)^ := I64 div IBScaleDivisor[-4-XSQLVAR.sqlscale] //dec scale digits
                    else
                      PISC_LONG(XSQLVAR.sqldata)^ := I64 * IBScaleDivisor[4+XSQLVAR.sqlscale]; //inc scale digits
    SQL_BOOLEAN   : PISC_BOOLEAN(XSQLVAR.sqldata)^ := Ord(Value <> 0);
    SQL_BOOLEAN_FB: PISC_BOOLEAN_FB(XSQLVAR.sqldata)^ := Ord(Value <> 0);
    SQL_SHORT     : if XSQLVAR.sqlscale = -4 then  //scale fits!
                      PISC_SHORT(XSQLVAR.sqldata)^ := I64
                    else if XSQLVAR.sqlscale > -4 then //EH: check the modulo?
                      PISC_SHORT(XSQLVAR.sqldata)^ := I64 div IBScaleDivisor[-4-XSQLVAR.sqlscale] //dec scale digits
                    else
                      PISC_SHORT(XSQLVAR.sqldata)^ := I64 * IBScaleDivisor[4+XSQLVAR.sqlscale]; //inc scale digits
    SQL_INT64,
    SQL_QUAD      : if XSQLVAR.sqlscale = -4 then //scale fits!
                      PISC_INT64(XSQLVAR.sqldata)^ := I64
                    else if XSQLVAR.sqlscale > -4 then //EH: check the modulo?
                      PISC_INT64(XSQLVAR.sqldata)^ := I64 div IBScaleDivisor[-4-XSQLVAR.sqlscale]//dec scale digits
                    else
                      PISC_INT64(XSQLVAR.sqldata)^ := I64 * IBScaleDivisor[4+XSQLVAR.sqlscale]; //inc scale digits
    SQL_TEXT,
    SQL_VARYING   : begin
                      CurrToRaw(Value, @fABuffer[0], @P);
                      EncodePData(XSQLVAR, @fABuffer[0], P-PAnsiChar(@fABuffer[0]));
                      Exit;
                    end;
    else raise EZIBConvertError.Create(SUnsupportedDataType);
  end;
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;

{**
  Sets the designated parameter to a <code<java.sql.Date</code> value.
  The driver converts this to an SQL <code>DATE</code>
  value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
{$IFDEF FPC} {$PUSH} {$WARN 5057 off : Local variable "$1" does not seem to be initialized} {$ENDIF}
procedure TZInterbase6PreparedStatement.SetDate(Index: Integer;
  const Value: TZDate);
var XSQLVAR: PXSQLVAR;
  DT: TDateTime;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  case (XSQLVAR.sqltype and not(1)) of
    SQL_TEXT,
    SQL_VARYING   : begin
                      EncodePData(XSQLVAR, @fABuffer,
                        DateToRaw(Value.Year, Value.Month, Value.Day, @fABuffer,
                          ConSettings^.WriteFormatSettings.DateFormat, False, Value.IsNegative));
                      Exit;
                    end;
    SQL_TYPE_DATE : isc_encode_date(PISC_DATE(XSQLVAR.sqldata)^, Value.Year, Value.Month, Value.Day);
    SQL_TIMESTAMP : begin
                      isc_encode_date(PISC_TIMESTAMP(XSQLVAR.sqldata).timestamp_date, Value.Year, Value.Month, Value.Day);
                      PISC_TIMESTAMP(XSQLVAR.sqldata).timestamp_time := 0;
                    end;
    else begin
      ZSysUtils.TryDateToDateTime(Value, DT);
      InternalBindDouble(XSQLVAR, DT);
      Exit;
    end;
  end;
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;
{$IFDEF FPC} {$POP} {$ENDIF}

{**
  Sets the designated parameter to a Java <code>double</code> value.
  The driver converts this
  to an SQL <code>DOUBLE</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetDouble(Index: Integer;
  const Value: Double);
var XSQLVAR: PXSQLVAR;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  case (XSQLVAR.sqltype and not(1)) of
    SQL_TEXT,
    SQL_VARYING   : EncodePData(XSQLVAR, @fABuffer[0], FloatToSqlRaw(Value, @fABuffer[0]));
    else InternalBindDouble(XSQLVAR, Value);
  end;
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;

{**
  Sets the designated parameter to a Java <code>float</code> value.
  The driver converts this
  to an SQL <code>FLOAT</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetFloat(Index: Integer;
  Value: Single);
var XSQLVAR: PXSQLVAR;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  case (XSQLVAR.sqltype and not(1)) of
    SQL_FLOAT     : PSingle(XSQLVAR.sqldata)^   := Value;
    SQL_TEXT,
    SQL_VARYING   : EncodePData(XSQLVAR, @fABuffer[0], FloatToSqlRaw(Value, @fABuffer[0]));
    else InternalBindDouble(XSQLVAR, Value);
  end;
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;

{**
  Sets the designated parameter to a GUID.
  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetGUID(Index: Integer;
  const Value: TGUID);
var XSQLVAR: PXSQLVAR;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  case (XSQLVAR.sqltype and not(1)) of
    SQL_TEXT,
    SQL_VARYING   : if XSQLVAR.sqlsubtype = CS_BINARY then
                      EncodePData(XSQLVAR, @Value.D1, SizeOf(TGUID))
                    else begin
                      //see https://firebirdsql.org/refdocs/langrefupd25-intfunc-uuid_to_char.html
                      GUIDToBuffer(@Value.D1, PAnsiChar(@fABuffer), []);
                      EncodePData(XSQLVAR, @fABuffer, 36)
                    end;
    SQL_BLOB,
    SQL_QUAD      : if XSQLVAR.sqlsubtype = CS_BINARY then
                      WriteLobBuffer(XSQLVAR, @Value.D1, SizeOf(TGUID))
                    else begin
                      GUIDToBuffer(@Value.D1, PAnsiChar(@fABuffer), []);
                      WriteLobBuffer(XSQLVAR, @fABuffer, 36)
                    end;
    else raise EZIBConvertError.Create(SUnsupportedDataType);
  end;
end;

{**
  Sets the designated parameter to a Java <code>int</code> value.
  The driver converts this
  to an SQL <code>INTEGER</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
procedure TZInterbase6PreparedStatement.AddParamLogValue(ParamIndex: Integer;
  SQLWriter: TZRawSQLStringWriter; var Result: RawByteString);
var XSQLVAR: PXSQLVAR;
  TempDate: TZTimeStamp;
  Buffer: array[0..SizeOf(TZTimeStamp)-1] of AnsiChar absolute TempDate;
  dDT, tDT: TDateTime;
  P: PAnsiChar;
begin
  CheckParameterIndex(ParamIndex);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[ParamIndex];
  {$IF defined(RangeCheckEnabled) and not defined(WITH_UINT64_C1118_ERROR)}{$R+} {$IFEND}
  if (XSQLVAR.sqlind <> nil) and (XSQLVAR.sqlind^ = ISC_NULL) then
    Result := '(NULL)'
  else case XSQLVAR.sqltype and not(1) of
    SQL_ARRAY     : SQLWriter.AddText('(ARRAY)', Result);
    SQL_D_FLOAT,
    SQL_DOUBLE    : SQLWriter.AddFloat(PDouble(XSQLVAR.sqldata)^, Result);
    SQL_FLOAT     : SQLWriter.AddFloat(PSingle(XSQLVAR.sqldata)^, Result);
    SQL_BOOLEAN   : if PISC_BOOLEAN(XSQLVAR.sqldata)^ <> 0
                    then SQLWriter.AddText('(TRUE)', Result)
                    else SQLWriter.AddText('(FALSE)', Result);
    SQL_BOOLEAN_FB: if PISC_BOOLEAN_FB(XSQLVAR.sqldata)^ <> 0
                    then SQLWriter.AddText('(TRUE)', Result)
                    else SQLWriter.AddText('(FALSE)', Result);
    SQL_SHORT     : if XSQLVAR.sqlscale = 0
                    then SQLWriter.AddOrd(PISC_SHORT(XSQLVAR.sqldata)^, Result)
                    else begin
                      ScaledOrdinal2Raw(Integer(PISC_SHORT(XSQLVAR.sqldata)^), @Buffer[0], @P, Byte(-IBScaleDivisor[XSQLVAR.sqlscale]));
                      SQLWriter.AddText(@Buffer[0], P - PAnsiChar(@Buffer[0]), Result);
                    end;
    SQL_LONG      : if XSQLVAR.sqlscale = 0
                    then SQLWriter.AddOrd(PISC_LONG(XSQLVAR.sqldata)^, Result)
                    else begin
                      ScaledOrdinal2Raw(PISC_LONG(XSQLVAR.sqldata)^, @Buffer[0], @P, Byte(-IBScaleDivisor[XSQLVAR.sqlscale]));
                      SQLWriter.AddText(@Buffer[0], P - PAnsiChar(@Buffer[0]), Result);
                    end;
    SQL_QUAD,
    SQL_INT64     : if XSQLVAR.sqlscale = 0
                    then SQLWriter.AddOrd(PInt64(XSQLVAR.sqldata)^, Result)
                    else begin
                      ScaledOrdinal2Raw(PInt64(XSQLVAR.sqldata)^, @Buffer[0], @P, Byte(-IBScaleDivisor[XSQLVAR.sqlscale]));
                      SQLWriter.AddText(@Buffer[0], P - PAnsiChar(@Buffer[0]), Result);
                    end;
    SQL_TEXT      : if XSQLVAR.sqlsubtype and 255 = CS_BINARY
                    then SQLWriter.AddHexBinary(PByte(XSQLVAR.sqldata), XSQLVAR.sqllen, False, Result)
                    else SQLWriter.AddTextQuoted(PAnsiChar(XSQLVAR.sqldata), XSQLVAR.sqllen, AnsiChar(#39), Result);
    SQL_VARYING   : if XSQLVAR.sqlsubtype and 255 = CS_BINARY
                    then SQLWriter.AddHexBinary(PByte(@PISC_VARYING(XSQLVAR.sqldata).str[0]), PISC_VARYING(XSQLVAR.sqldata).strlen, False, Result)
                    else SQLWriter.AddTextQuoted(PAnsiChar(@PISC_VARYING(XSQLVAR.sqldata).str[0]), PISC_VARYING(XSQLVAR.sqldata).strlen, AnsiChar(#39), Result);
    SQL_BLOB      : if XSQLVAR.sqlsubtype = isc_blob_text
                    then SQLWriter.AddText('(CLOB)', Result)
                    else SQLWriter.AddText('(BLOB)', Result);
    SQL_TYPE_TIME : begin
                      isc_decode_time(PISC_TIME(XSQLVAR.sqldata)^,
                        TempDate.Hour, TempDate.Minute, Tempdate.Second, Tempdate.Fractions);
                      if TryEncodeTime(TempDate.Hour, TempDate.Minute, TempDate.Second, TempDate.Fractions div 10, tDT)
                      then SQLWriter.AddTime(tDT, ConSettings.WriteFormatSettings.TimeFormat, Result)
                      else SQLWriter.AddText('(TIME)', Result);
                    end;
    SQL_TYPE_DATE : begin
                      isc_decode_date(PISC_DATE(XSQLVAR.sqldata)^,
                        TempDate.Year, TempDate.Month, Tempdate.Day);
                      if TryEncodeDate(TempDate.Year,TempDate.Month, TempDate.Day, dDT)
                      then SQLWriter.AddDate(dDT, ConSettings.WriteFormatSettings.DateFormat, Result)
                      else SQLWriter.AddText('(DATE)', Result);
                    end;
    SQL_TIMESTAMP : begin
                      isc_decode_time(PISC_TIMESTAMP(XSQLVAR.sqldata).timestamp_time,
                        TempDate.Hour, TempDate.Minute, Tempdate.Second, Tempdate.Fractions);
                      isc_decode_date(PISC_TIMESTAMP(XSQLVAR.sqldata).timestamp_date,
                        TempDate.Year, TempDate.Month, Tempdate.Day);
                      if not TryEncodeTime(TempDate.Hour, TempDate.Minute, TempDate.Second, TempDate.Fractions div 10, tDT) then
                        tDT := 0;
                      if not TryEncodeDate(TempDate.Year,TempDate.Month, TempDate.Day, dDT) then
                        dDT := 0;
                      if dDT < 0
                      then dDT := dDT-tDT
                      else dDT := dDT+tDT;
                      SQLWriter.AddDateTime(dDT, ConSettings.WriteFormatSettings.DateTimeFormat, Result)
                    end;
    else            SQLWriter.AddText('(UNKNOWN)', Result);
  end;
end;
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}

procedure TZInterbase6PreparedStatement.SetInt(Index, Value: Integer);
var XSQLVAR: PXSQLVAR;
  P: PAnsiChar;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  case (XSQLVAR.sqltype and not(1)) of
    SQL_FLOAT     : PSingle(XSQLVAR.sqldata)^   := Value;
    SQL_D_FLOAT,
    SQL_DOUBLE    : PDouble(XSQLVAR.sqldata)^   := Value;
    SQL_LONG      : if XSQLVAR.sqlscale = 0
                    then PISC_LONG(XSQLVAR.sqldata)^ := Value
                    else PISC_LONG(XSQLVAR.sqldata)^ := Value*IBScaleDivisor[XSQLVAR.sqlscale];
    SQL_BOOLEAN   : PISC_BOOLEAN(XSQLVAR.sqldata)^ := Ord(Value <> 0);
    SQL_BOOLEAN_FB: PISC_BOOLEAN_FB(XSQLVAR.sqldata)^ := Ord(Value <> 0);
    SQL_SHORT     : if XSQLVAR.sqlscale = 0
                    then PISC_SHORT(XSQLVAR.sqldata)^ := Value
                    else PISC_SHORT(XSQLVAR.sqldata)^ := Value*IBScaleDivisor[XSQLVAR.sqlscale];
    SQL_INT64,
    SQL_QUAD      : if XSQLVAR.sqlscale = 0
                    then PISC_INT64(XSQLVAR.sqldata)^ := Value
                    else PISC_INT64(XSQLVAR.sqldata)^ := Value*IBScaleDivisor[XSQLVAR.sqlscale];
    SQL_TEXT,
    SQL_VARYING   : begin
                      IntToRaw(Value, @fABuffer[0], @P);
                      EncodePData(XSQLVAR, @fABuffer[0], P-@fABuffer[0]);
                    end;
    else raise EZIBConvertError.Create(SUnsupportedDataType);
  end;
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;

{**
  Sets the designated parameter to a Java <code>unsigned longlong</code> value.
  The driver converts this
  to an SQL <code>BIGINT</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetLong(Index: Integer;
  const Value: Int64);
var XSQLVAR: PXSQLVAR;
  P: PAnsiChar;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  case (XSQLVAR.sqltype and not(1)) of
    SQL_FLOAT     : PSingle(XSQLVAR.sqldata)^   := Value;
    SQL_D_FLOAT,
    SQL_DOUBLE    : PDouble(XSQLVAR.sqldata)^   := Value;
    SQL_LONG      : if XSQLVAR.sqlscale = 0
                    then PISC_LONG(XSQLVAR.sqldata)^ := Value
                    else PISC_LONG(XSQLVAR.sqldata)^ := Value*IBScaleDivisor[XSQLVAR.sqlscale];
    SQL_BOOLEAN   : PISC_BOOLEAN(XSQLVAR.sqldata)^ := Ord(Value <> 0);
    SQL_BOOLEAN_FB: PISC_BOOLEAN_FB(XSQLVAR.sqldata)^ := Ord(Value <> 0);
    SQL_SHORT     : if XSQLVAR.sqlscale = 0
                    then PISC_SHORT(XSQLVAR.sqldata)^ := Value
                    else PISC_SHORT(XSQLVAR.sqldata)^ := Value*IBScaleDivisor[XSQLVAR.sqlscale];
    SQL_INT64,
    SQL_QUAD      : if XSQLVAR.sqlscale = 0
                    then PISC_INT64(XSQLVAR.sqldata)^ := Value
                    else PISC_INT64(XSQLVAR.sqldata)^ := Value*IBScaleDivisor[XSQLVAR.sqlscale];
    SQL_TEXT,
    SQL_VARYING   : begin
                      IntToRaw(Value, @fABuffer[0], @P);
                      EncodePData(XSQLVAR, @fABuffer[0], P-@fABuffer[0]);
                    end;
    else raise EZIBConvertError.Create(SUnsupportedDataType);
  end;
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;

{**
  Sets the designated parameter to SQL <code>NULL</code>.
  <P><B>Note:</B> You must specify the parameter's SQL type.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param sqlType the SQL type code defined in <code>java.sql.Types</code>
}
procedure TZInterbase6PreparedStatement.SetNull(Index: Integer;
  SQLType: TZSQLType);
var XSQLVAR: PXSQLVAR;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  if (XSQLVAR.sqlind <> nil) then
    XSQLVAR.sqlind^ := ISC_NULL;
end;

{**
   Set up parameter PAnsiChar value
   @param Index the target parameter index
   @param Value the source value
}
{$IFDEF FPC} {$PUSH} {$WARN 5057 off : Local variable "$1" does not seem to be initialized} {$ENDIF}
procedure TZInterbase6PreparedStatement.SetPAnsiChar(Index: Word;
  Value: PAnsiChar; Len: LengthInt);
var
  TS: TZTimeStamp;
  D: TZDate absolute TS;
  T: TZTime absolute TS;
  XSQLVAR: PXSQLVAR;
Label Fail;
begin
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  case (XSQLVAR.sqltype and not(1)) of
    SQL_TEXT      : EncodePData(XSQLVAR, Value, Len);
    SQL_VARYING   : EncodePData(XSQLVAR, Value, Len);
    SQL_LONG      : PISC_LONG (XSQLVAR.sqldata)^ := RawToIntDef(Value, Value+Len, 0);
    SQL_SHORT     : PISC_SHORT (XSQLVAR.sqldata)^ := RawToIntDef(Value, Value+Len,0);
    SQL_BOOLEAN   : PISC_BOOLEAN(XSQLVAR.sqldata)^ := Ord(StrToBoolEx(Value, Value+Len));
    SQL_BOOLEAN_FB: PISC_BOOLEAN_FB(XSQLVAR.sqldata)^ := Ord(StrToBoolEx(Value, Value+Len));
    SQL_D_FLOAT,
    SQL_DOUBLE    : SQLStrToFloatDef(Value, 0, PDouble(XSQLVAR.sqldata)^, Len);
    SQL_FLOAT     : SQLStrToFloatDef(Value, 0, PSingle (XSQLVAR.sqldata)^, Len);
    SQL_INT64     : PISC_INT64(XSQLVAR.sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(RoundTo(SQLStrToFloatDef(Value, 0, Len) * IBScaleDivisor[XSQLVAR.sqlscale], 0)); //AVZ - INT64 value was not recognized
    SQL_BLOB, SQL_QUAD: WriteLobBuffer(XSQLVAR, Value, Len);
    SQL_TYPE_DATE : if TryPCharToDate(Value, Len, ConSettings^.WriteFormatSettings, D)
                    then isc_encode_date(PISC_DATE(XSQLVAR.sqldata)^, D.Year, D.Month, D.Day)
                    else goto Fail;
    SQL_TYPE_TIME:  if TryPCharToTime(Value, Len, ConSettings^.WriteFormatSettings, T)
                    then isc_encode_time(PISC_TIME(XSQLVAR.sqldata)^, T.Hour, T.Minute, T.Second, T.Fractions div 100000)
                    else goto Fail;
    SQL_TIMESTAMP:  if TryPCharToTimeStamp(Value, Len, ConSettings^.WriteFormatSettings, TS) then begin
                      isc_encode_date(PISC_TIMESTAMP(XSQLVAR.sqldata).timestamp_date, TS.Year, TS.Month, TS.Day);
                      isc_encode_time(PISC_TIMESTAMP(XSQLVAR.sqldata).timestamp_time, TS.Hour, TS.Minute, TS.Second, TS.Fractions div 100000);
                    end else goto Fail;
    else
Fail: raise EZIBConvertError.Create(SErrorConvertion);
  end;
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;
{$IFDEF FPC} {$POP} {$ENDIF}

{$IFDEF FPC} {$PUSH} {$WARN 5057 off : Local variable "$1" does not seem to be initialized} {$ENDIF}
procedure TZInterbase6PreparedStatement.SetPWideChar(Index: Word;
  Value: PWideChar; Len: LengthInt);
var
  TS: TZTimeStamp;
  D: TZDate absolute TS;
  T: TZTime absolute TS;
  XSQLVAR: PXSQLVAR;
Label Fail;
begin
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  case (XSQLVAR.sqltype and not(1)) of
    SQL_TEXT,
    SQL_VARYING   : begin
                      if XSQLVAR.sqlsubtype and 255 <> CS_BINARY then
                        if (FDB_CP_ID <> CS_NONE)
                        then FRawTemp := PUnicodeToRaw(Value, Len, FClientCP)
                        else FRawTemp := PUnicodeToRaw(Value, Len, FCodePageArray[XSQLVAR.sqlsubtype and 255])
                      else FRawTemp := UnicodeStringToAscii7(Value, Len);
                      if FRawTemp <> ''
                      then EncodePData(XSQLVAR, Pointer(FRawTemp), Length(FRawTemp))
                      else EncodePData(XSQLVAR, PEmptyAnsiString, 0)
                    end;
    SQL_LONG      : PISC_LONG(XSQLVAR.sqldata)^ := UnicodeToIntDef(Value, Value+Len, 0);
    SQL_SHORT     : PISC_SHORT(XSQLVAR.sqldata)^ := UnicodeToIntDef(Value, Value+Len,0);
    SQL_BOOLEAN   : PISC_BOOLEAN(XSQLVAR.sqldata)^ := Ord(StrToBoolEx(Value, Value+Len));
    SQL_BOOLEAN_FB: PISC_BOOLEAN_FB(XSQLVAR.sqldata)^ := Ord(StrToBoolEx(Value, Value+Len));
    SQL_D_FLOAT,
    SQL_DOUBLE    : SQLStrToFloatDef(Value, 0, PDouble(XSQLVAR.sqldata)^, Len);
    SQL_FLOAT     : SQLStrToFloatDef(Value, 0, PSingle (XSQLVAR.sqldata)^, Len);
    SQL_INT64     : PISC_INT64(XSQLVAR.sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(RoundTo(SQLStrToFloatDef(Value, 0, Len) * IBScaleDivisor[XSQLVAR.sqlscale], 0)); //AVZ - INT64 value was not recognized
    SQL_BLOB,
    SQL_QUAD      : begin
                      if XSQLVAR.sqlsubtype = isc_blob_text
                      then FRawTemp := PUnicodeToRaw(Value, Len, FClientCP)
                      else FRawTemp := UnicodeStringToAscii7(Value, Len);
                      if FRawTemp <> ''
                      then WriteLobBuffer(XSQLVAR, Pointer(FRawTemp), Length(FRawTemp))
                      else WriteLobBuffer(XSQLVAR, PEmptyAnsiString, 0)
                    end;
    SQL_TYPE_DATE : if TryPCharToDate(Value, Len, ConSettings^.WriteFormatSettings, D)
                    then isc_encode_date(PISC_DATE(XSQLVAR.sqldata)^, D.Year, D.Month, D.Day)
                    else goto Fail;
    SQL_TYPE_TIME:  if TryPCharToTime(Value, Len, ConSettings^.WriteFormatSettings, T)
                    then isc_encode_time(PISC_TIME(XSQLVAR.sqldata)^, T.Hour, T.Minute, T.Second, T.Fractions div 100000)
                    else goto Fail;
    SQL_TIMESTAMP:  if TryPCharToTimeStamp(Value, Len, ConSettings^.WriteFormatSettings, TS) then begin
                      isc_encode_date(PISC_TIMESTAMP(XSQLVAR.sqldata).timestamp_date, TS.Year, TS.Month, TS.Day);
                      isc_encode_time(PISC_TIMESTAMP(XSQLVAR.sqldata).timestamp_time, TS.Hour, TS.Minute, TS.Second, TS.Fractions div 100000);
                    end else goto Fail;
    else
Fail:   raise EZIBConvertError.Create(SErrorConvertion);
  end;
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;
{$IFDEF FPC} {$POP} {$ENDIF}

{**
  Sets the designated parameter to a Java <code>raw encoded string</code> value.
  The driver converts this
  to an SQL <code>VARCHAR</code> or <code>LONGVARCHAR</code> value
  (depending on the argument's
  size relative to the driver's limits on <code>VARCHAR</code> values)
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetRawByteString(
  Index: Integer; const Value: RawByteString);
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if Value <> ''
  then SetPAnsiChar(Index, Pointer(Value), Length(Value))
  else SetPAnsiChar(Index, PEmptyAnsiString, 0)
end;

{**
  Sets the designated parameter to a Java <code>ShortInt</code> value.
  The driver converts this
  to an SQL <code>ShortInt</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetShort(Index: Integer;
  Value: ShortInt);
begin
  SetSmall(Index, Value);
end;

{**
  Sets the designated parameter to a Java <code>SmallInt</code> value.
  The driver converts this
  to an SQL <code>SMALLINT</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetSmall(
  Index: Integer; Value: SmallInt);
var XSQLVAR: PXSQLVAR;
  P: PAnsiChar;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  case (XSQLVAR.sqltype and not(1)) of
    SQL_FLOAT     : PSingle(XSQLVAR.sqldata)^   := Value;
    SQL_D_FLOAT,
    SQL_DOUBLE    : PDouble(XSQLVAR.sqldata)^   := Value;
    SQL_LONG      : if XSQLVAR.sqlscale = 0
                    then PISC_LONG(XSQLVAR.sqldata)^ := Value
                    else PISC_LONG(XSQLVAR.sqldata)^ := Value*IBScaleDivisor[XSQLVAR.sqlscale];
    SQL_BOOLEAN   : PISC_BOOLEAN(XSQLVAR.sqldata)^ := Ord(Value <> 0);
    SQL_BOOLEAN_FB: PISC_BOOLEAN_FB(XSQLVAR.sqldata)^ := Ord(Value <> 0);
    SQL_SHORT     : if XSQLVAR.sqlscale = 0
                    then PISC_SHORT(XSQLVAR.sqldata)^ := Value
                    else PISC_SHORT(XSQLVAR.sqldata)^ := Value*IBScaleDivisor[XSQLVAR.sqlscale];
    SQL_INT64,
    SQL_QUAD      : if XSQLVAR.sqlscale = 0
                    then PISC_INT64(XSQLVAR.sqldata)^ := Value
                    else PISC_INT64(XSQLVAR.sqldata)^ := Value*IBScaleDivisor[XSQLVAR.sqlscale];
    SQL_TEXT,
    SQL_VARYING   : begin
                      IntToRaw(Integer(Value), @fABuffer[0], @P);
                      EncodePData(XSQLVAR, @fABuffer[0], P-@fABuffer[0]);
                    end;
    else raise EZIBConvertError.Create(SUnsupportedDataType);
  end;
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;

{**
  Sets the designated parameter to a Java <code>String</code> value.
  The driver converts this
  to an SQL <code>VARCHAR</code> or <code>LONGVARCHAR</code> value
  (depending on the argument's
  size relative to the driver's limits on <code>VARCHAR</code> values)
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetString(Index: Integer;
  const Value: String);
{$IFDEF UNICODE}
begin
  SetUnicodeString(Index, Value);
{$ELSE}
var XSQLVAR: PXSQLVAR;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if Value <> '' then begin
    {$R-}
    XSQLVAR := @FParamXSQLDA.sqlvar[Index];
    {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    case (XSQLVAR.sqltype and not(1)) of
      SQL_TEXT,
      SQL_VARYING   : if not ConSettings^.AutoEncode or (XSQLVAR.sqlsubtype and 255 = CS_BINARY) then
                        EncodePData(XSQLVAR, Pointer(Value), Length(Value))
                      else if (ClientCP <> CS_NONE)
                        then SetRawByteString(Index{$IFNDEF GENERIC_INDEX}+1{$ENDIF},
                          ConSettings^.ConvFuncs.ZStringToRaw( Value, ConSettings^.Ctrl_CP, ClientCP))
                        else SetRawByteString(Index{$IFNDEF GENERIC_INDEX}+1{$ENDIF},
                          ConSettings^.ConvFuncs.ZStringToRaw( Value, ConSettings^.Ctrl_CP, FCodePageArray[XSQLVAR.sqlsubtype and 255]));
      SQL_BLOB,
      SQL_QUAD      : if not ConSettings^.AutoEncode or (XSQLVAR.sqlsubtype <> isc_blob_text)
                      then WriteLobBuffer(XSQLVAR, Pointer(Value), Length(Value))
                      else SetRawByteString(Index{$IFNDEF GENERIC_INDEX}+1{$ENDIF},
                          ConSettings^.ConvFuncs.ZStringToRaw( Value, ConSettings^.Ctrl_CP, ClientCP));
      else SetPAnsiChar(Index, Pointer(Value), Length(Value));
    end;
  end else
    SetPAnsiChar(Index, PEmptyAnsiString, 0)
  {$ENDIF}
end;

{**
  Sets the designated parameter to a <code>java.sql.Time</code> value.
  The driver converts this to an SQL <code>TIME</code> value
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
{$IFDEF FPC} {$PUSH} {$WARN 5057 off : Local variable "$1" does not seem to be initialized} {$ENDIF}
procedure TZInterbase6PreparedStatement.SetTime(Index: Integer;
  const Value: TZTime);
var XSQLVAR: PXSQLVAR;
  DT: TDateTime;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  case (XSQLVAR.sqltype and not(1)) of
    SQL_TEXT,
    SQL_VARYING   : begin
                      EncodePData(XSQLVAR, @fABuffer,
                        TimeToRaw(Value.Hour, Value.Minute, Value.Second, Value.Fractions,
                          @fABuffer, ConSettings^.WriteFormatSettings.TimeFormat, False, False));
                      Exit;
                    end;
    SQL_TYPE_TIME : isc_encode_time(PISC_TIME(XSQLVAR.sqldata)^, Value.Hour, Value.Minute, Value.Second, Value.Fractions div 100000);
    SQL_TIMESTAMP : begin
                      isc_encode_date(PISC_TIMESTAMP(XSQLVAR.sqldata).timestamp_date,
                        cPascalIntegralDatePart.Year, cPascalIntegralDatePart.Month, cPascalIntegralDatePart.Day);
                      isc_encode_time(PISC_TIMESTAMP(XSQLVAR.sqldata).timestamp_time, Value.Hour, Value.Minute, Value.Second, Value.Fractions div 100000);
                    end;
    else            begin
                      ZSysUtils.TryTimeToDateTime(Value, DT);
                      InternalBindDouble(XSQLVAR, DT);
                      Exit;
                    end;
  end;
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;
{$IFDEF FPC} {$POP} {$ENDIF}

{**
  Sets the designated parameter to a <code>java.sql.Timestamp</code> value.
  The driver converts this to an SQL <code>TIMESTAMP</code> value
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
{$IFDEF FPC} {$PUSH} {$WARN 5057 off : Local variable "$1" does not seem to be initialized} {$ENDIF}
procedure TZInterbase6PreparedStatement.SetTimestamp(
  Index: Integer; const Value: TZTimeStamp);
var XSQLVAR: PXSQLVAR;
  DT: TDateTime;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  {$R-}
  XSQLVAR := @FParamXSQLDA.sqlvar[Index];
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  case (XSQLVAR.sqltype and not(1)) of
    SQL_TEXT,
    SQL_VARYING   : begin
                      EncodePData(XSQLVAR, @fABuffer,
                        DateTimeToRaw(Value.Year, Value.Month, Value.Day,
                          Value.Hour, Value.Minute, Value.Second, Value.Fractions,
                          @fABuffer, ConSettings^.WriteFormatSettings.DateTimeFormat, False, Value.IsNegative));
                      Exit;
                    end;
    SQL_TYPE_DATE : isc_encode_date(PISC_DATE(XSQLVAR.sqldata)^, Value.Year, Value.Month, Value.Day);
    SQL_TYPE_TIME : isc_encode_time(PISC_TIME(XSQLVAR.sqldata)^, Value.Hour, Value.Minute, Value.Second, Value.Fractions div 100000);
    SQL_TIMESTAMP : begin
                      isc_encode_date(PISC_TIMESTAMP(XSQLVAR.sqldata).timestamp_date, Value.Year, Value.Month, Value.Day);
                      isc_encode_time(PISC_TIMESTAMP(XSQLVAR.sqldata).timestamp_time, Value.Hour, Value.Minute, Value.Second, Value.Fractions div 100000);
                    end;
    else begin
      ZSysUtils.TryTimeStampToDateTime(Value, DT);
      InternalBindDouble(XSQLVAR, DT);
      Exit;
    end;
  end;
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;
{$IFDEF FPC} {$POP} {$ENDIF}

{**
  Sets the designated parameter to a Java <code>usigned int</code> value.
  The driver converts this
  to an SQL <code>INTEGER</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetUInt(Index: Integer;
  Value: Cardinal);
begin
  SetLong(Index, Value);
end;

{**
  Sets the designated parameter to a Java <code>unsigned longlong</code> value.
  The driver converts this
  to an SQL <code>BIGINT</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetULong(Index: Integer;
  const Value: UInt64);
begin
  {$IFDEF WITH_UINT64_C1118_ERROR}
  SetLong(Index, UInt64ToInt64(Value));
  {$ELSE}
  SetLong(Index, Value);
  {$ENDIF}
end;

{**
  Sets the designated parameter to a Java <code>UnicodeString</code> value.
  The driver converts this
  to an SQL <code>VARCHAR</code> or <code>LONGVARCHAR</code> value
  (depending on the argument's
  size relative to the driver's limits on <code>VARCHAR</code> values)
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetUnicodeString(
  Index: Integer; const Value: ZWideString);
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if Value <> ''
  then SetPWideChar(Index, Pointer(Value), Length(Value))
  else SetPAnsiChar(Index, PEmptyAnsiString, 0);
end;

{**
  Sets the designated parameter to a Java <code>UTF8String</code> value.
  The driver converts this
  to an SQL <code>VARCHAR</code> or <code>LONGVARCHAR</code> value
  (depending on the argument's
  size relative to the driver's limits on <code>VARCHAR</code> values)
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
{$IFNDEF NO_UTF8STRING}
procedure TZInterbase6PreparedStatement.SetUTF8String(Index: Integer;
  const Value: UTF8String);
var XSQLVAR: PXSQLVAR;
  P: PAnsiChar;
  CP_ID: SmallInt;
  Len: LengthInt;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if Value <> '' then begin
    {$R-}
    XSQLVAR := @FParamXSQLDA.sqlvar[Index];
    {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    P := Pointer(Value);
    Len := Length(Value);
    case (XSQLVAR.sqltype and not(1)) of
      SQL_TEXT,
      SQL_VARYING   : begin
                      CP_ID := XSQLVAR.sqlsubtype and 255;
                      if (CP_ID = CS_UTF8) or (CP_ID = CS_UNICODE_FSS) or (CP_ID = CS_BINARY)
                      then EncodePData(XSQLVAR, P, Len)
                      else begin
                        PRawToRawConvert(P, Len, zCP_UTF8, FCodePageArray[CP_ID], FRawTemp);
                        Len := Length(FRawTemp);
                        if Len = 0
                        then P := PEmptyAnsiString
                        else P := Pointer(FRawTemp);
                        EncodePData(XSQLVAR, P, Len);
                      end;
                    end;
      SQL_BLOB,
      SQL_QUAD      : if XSQLVAR.sqlsubtype = isc_blob_text then
                        if (ClientCP = zCP_UTF8) then
                          WriteLobBuffer(XSQLVAR, Pointer(Value), Length(Value))
                        else begin
                          PRawToRawConvert(P, Len, zCP_UTF8, FClientCP, FRawTemp);
                          Len := Length(FRawTemp);
                          if Len = 0
                          then P := PEmptyAnsiString
                          else P := Pointer(FRawTemp);
                          WriteLobBuffer(XSQLVAR, P, Len);
                        end
                      else WriteLobBuffer(XSQLVAR, P, Len);
      else SetPAnsiChar(Index, P, Len);
    end;
  end else
    SetPAnsiChar(Index, PEmptyAnsiString, 0)
end;
{$ENDIF NO_UTF8STRING}

{**
  Sets the designated parameter to a Java <code>SmallInt</code> value.
  The driver converts this
  to an SQL <code>SMALLINT</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZInterbase6PreparedStatement.SetWord(Index: Integer;
  Value: Word);
begin
  SetInt(Index, Value);
end;

{**
  Removes eventual structures for binding input parameters.
}
procedure TZInterbase6PreparedStatement.UnPrepareInParameters;
begin
  if assigned(FParamSQLData) then begin
    FParamSQLData.FreeParamtersValues;
    FParamXSQLDA := nil;
  end;
  inherited UnPrepareInParameters;
end;

procedure TZInterbase6PreparedStatement.WriteLobBuffer(XSQLVAR: PXSQLVAR;
  Buffer: Pointer; Len: LengthInt);
var
  BlobId: TISC_QUAD;
  BlobHandle: TISC_BLOB_HANDLE;
  StatusVector: TARRAY_ISC_STATUS;
  CurPos, SegLen: Integer;
  TempBuffer: PAnsiChar;
begin
  BlobHandle := 0;

  { create blob handle }
  with FIBConnection do
    if FPlainDriver.isc_create_blob2(@StatusVector, GetDBHandle, GetTrHandle,
      @BlobHandle, @BlobId, 0, nil) <> 0 then
    CheckInterbase6Error(FPlainDriver, StatusVector, Self);

  { put data to blob }
  TempBuffer := Buffer;
  CurPos := 0;
  SegLen := DefaultBlobSegmentSize;
  while (CurPos < Len) do begin
    if (CurPos + SegLen > Len) then
      SegLen := Len - CurPos;
    if FPlainDriver.isc_put_segment(@StatusVector, @BlobHandle, SegLen, TempBuffer) <> 0 then
      CheckInterbase6Error(FPlainDriver, StatusVector, Self);
    Inc(CurPos, SegLen);
    Inc(TempBuffer, SegLen);
  end;

  { close blob handle }
  if FPlainDriver.isc_close_blob(@StatusVector, @BlobHandle) <> 0 then
    CheckInterbase6Error(FPlainDriver, StatusVector, Self);
  PISC_QUAD(XSQLVAR.sqldata)^ := BlobId;
  if (XSQLVAR.sqlind <> nil) then
     XSQLVAR.sqlind^ := ISC_NOTNULL;
end;

{ TZInterbase6Statement }

constructor TZInterbase6Statement.Create(const Connection: IZConnection;
  Info: TStrings);
begin
  inherited Create(Connection, '', Info);
end;

{ TZInterbase6CallableStatement }

function TZInterbase6CallableStatement.CreateExecutionStatement(
  const StoredProcName: String): TZAbstractPreparedStatement;
var
  I: Integer;
  SQL: {$IF defined(FPC) and defined(WITH_RAWBYTESTRING)}RawByteString{$ELSE}String{$IFEND};
  SQLWriter: TZSQLStringWriter;
begin
  SQL := '';
  I := Length(StoredProcName);
  i := I + 6+BindList.Count shl 1;
  SQLWriter := TZSQLStringWriter.Create(I);
  if (Connection as IZInterbase6Connection).StoredProcedureIsSelectable(StoredProcName)
  then SQLWriter.AddText('SELECT * FROM ', SQL)
  else SQLWriter.AddText('EXECUTE PROCEDURE ', SQL);
  SQLWriter.AddText(StoredProcName, SQL);
  if BindList.Capacity >0 then
    SQLWriter.AddChar('(', SQL);
  for I := 0 to BindList.Capacity -1 do
    if not (BindList.ParamTypes[I] in [pctOut,pctReturn]) then
      SQLWriter.AddText('?,', SQL);
  if BindList.Capacity > 0 then begin
    SQLWriter.CancelLastComma(SQL);
    SQLWriter.AddChar(')', SQL);
  end;
  SQLWriter.Finalize(SQL);
  FreeAndNil(SQLWriter);
  Result := TZInterbase6PreparedStatement.Create(Connection, SQL, Info);
end;

{$ENDIF ZEOS_DISABLE_INTERBASE} //if set we have an empty unit
end.

