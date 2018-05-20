unit PasConv;

{$MODE Delphi}

interface

uses SysUtils, Classes, Parser;

type
  TPasTokenState = (tsAssembler, tsComment, tsCRLF, tsDirective,
    tsIdentifier, tsKeyWord, tsNumber, tsSpace,
    tsString, tsSymbol, tsUnknown);

  TFormatterBase = class
    function FormatToken(const NewToken: string; TokenState: TPasTokenState): string;
      virtual; abstract;
    procedure WriteFooter(OutStream: TStream); virtual; abstract;
    procedure WriteHeader(OutStream: TStream); virtual; abstract;
  end;

  TPasFormatter = class
  private
    FFormatter: TFormatterBase;
    FDiffer: boolean;
    FOutStream: TStream;
    FParser: TParser;
    procedure HandleAnsiC;
    procedure HandleBorC;
    procedure HandleCRLF;
    procedure HandleSlashesC;
    procedure HandleString;
    procedure HandleIdentifier;
    procedure HandleSpace;
    procedure HandleNumber;
    procedure HandleSymbol;
    procedure HandleMultilineComment;
    procedure HandleChar;
    procedure HandleHexNumber;
    function IsDiffKey(aToken: string): boolean;
    function IsDirective(aToken: string): boolean;
    function IsKeyWord(aToken: string): boolean;
    procedure WriteOut(tokenState: TPasTokenState; const str: string); overload;
    procedure WriteOut(tokenState: TPasTokenState); overload;
  public
    constructor Create(Formatter: TFormatterBase);
    procedure FormatStream(InStream, OutStream: TStream);
  end;

  TPasToRTF = class(TFormatterBase)
  private
    function SetSpecial(const str: string): string;
  public
    function FormatToken(const NewToken: string; TokenState: TPasTokenState): string;
      override;
    procedure WriteFooter(OutStream: TStream); override;
    procedure WriteHeader(OutStream: TStream); override;
  end;

  TPasToHTML = class(TFormatterBase)
  private
    function SetSpecial(const str: string): string;
  public
    function FormatToken(const NewToken: string; TokenState: TPasTokenState): string;
      override;
    procedure WriteFooter(OutStream: TStream); override;
    procedure WriteHeader(OutStream: TStream); override;
  end;

const
  PasKeywords: array[0..98] of string =
    ('ABSOLUTE', 'ABSTRACT', 'AND', 'ARRAY', 'AS', 'ASM', 'ASSEMBLER',
    'AUTOMATED', 'BEGIN', 'CASE', 'CDECL', 'CLASS', 'CONST', 'CONSTRUCTOR',
    'DEFAULT', 'DESTRUCTOR', 'DISPID', 'DISPINTERFACE', 'DIV', 'DO',
    'DOWNTO', 'DYNAMIC', 'ELSE', 'END', 'EXCEPT', 'EXPORT', 'EXPORTS',
    'EXTERNAL', 'FAR', 'FILE', 'FINALIZATION', 'FINALLY', 'FOR', 'FORWARD',
    'FUNCTION', 'GOTO', 'IF', 'IMPLEMENTATION', 'IN', 'INDEX', 'INHERITED',
    'INITIALIZATION', 'INLINE', 'INTERFACE', 'IS', 'LABEL', 'LIBRARY',
    'MESSAGE', 'MOD', 'NAME', 'NEAR', 'NIL', 'NODEFAULT', 'NOT', 'OBJECT',
    'OF', 'OR', 'OUT', 'OVERRIDE', 'PACKED', 'PASCAL', 'PRIVATE', 'PROCEDURE',
    'PROGRAM', 'PROPERTY', 'PROTECTED', 'PUBLIC', 'PUBLISHED', 'RAISE',
    'READ', 'READONLY', 'RECORD', 'REGISTER', 'REPEAT', 'RESIDENT',
    'RESOURCESTRING', 'SAFECALL', 'SET', 'SHL', 'SHR', 'STDCALL', 'STORED',
    'STRING', 'STRINGRESOURCE', 'THEN', 'THREADVAR', 'TO', 'TRY', 'TYPE',
    'UNIT', 'UNTIL', 'USES', 'VAR', 'VIRTUAL', 'WHILE', 'WITH', 'WRITE',
    'WRITEONLY', 'XOR');

  PasDirectives: array[0..10] of string =
    ('AUTOMATED', 'INDEX', 'NAME', 'NODEFAULT', 'READ', 'READONLY',
    'RESIDENT', 'STORED', 'STRINGRECOURCE', 'WRITE', 'WRITEONLY');

  PasDiffKeys: array[0..6] of string =
    ('END', 'FUNCTION', 'PRIVATE', 'PROCEDURE', 'PRODECTED',
    'PUBLIC', 'PUBLISHED');

procedure PasToHTMLFile(const PasFile, HTMLFile: string);
procedure PasToRTFFile(const PasFile, RTFFile: string);

implementation

procedure PasToHTMLFile(const PasFile, HTMLFile: string);
var
  fmt: TPasToHTML;
  p: TPasFormatter;
  stream1, stream2: TFileStream;
begin
  stream1 := TFileStream.Create(PasFile, fmOpenRead);
  stream2 := TFileStream.Create(HTMLFile, fmCreate);
  fmt := TPasToHTML.Create;
  p := TPasFormatter.Create(fmt);
  p.FormatStream(stream1, stream2);
  fmt.Free;
  stream1.Free;
  stream2.Free;
  p.Free;
end;

procedure PasToRTFFile(const PasFile, RTFFile: string);
var
  fmt: TPasToRTF;
  stream1, stream2: TFileStream;
  p: TPasFormatter;
begin
  stream1 := TFileStream.Create(PasFile, fmOpenRead);
  stream2 := TFileStream.Create(RTFFile, fmCreate);
  fmt := TPasToRTF.Create;
  p := TPasFormatter.Create(fmt);
  p.FormatStream(stream1, stream2);
  fmt.Free;
  stream1.Free;
  stream2.Free;
  p.Free;
end;

constructor TPasFormatter.Create(Formatter: TFormatterBase);
begin
  FFormatter := Formatter;
end;

procedure TPasFormatter.FormatStream(InStream, OutStream: TStream);
var
  oldPosition: integer;
begin
  FParser := TParser.Create(InStream);

  try
    FOutStream := OutStream;
    FFormatter.WriteHeader(OutStream);

    while not FParser.IsEof do
    begin
      oldPosition := FParser.Position;

      HandleCRLF;
      HandleSpace;
      HandleIdentifier;
      HandleNumber;
      HandleBorC;
      HandleSymbol;
      HandleString;
      HandleChar;
      HandleHexNumber;

      if oldPosition = FParser.Position then
      begin
        (* unexpected token, read one char and print it out immediately *)
        FParser.Next;
        WriteOut(tsUnknown);
      end;

    end;

    FFormatter.WriteFooter(OutStream);
  finally
    FParser.Free;
  end;
end;

(*
  Handles Ansi style comments, i.e. with parenthesis and stars.
*)
procedure TPasFormatter.HandleAnsiC;

  function IsEndOfAnsiComment: boolean;
  begin
    IsEndOfAnsiComment := (FParser.Current = '*') and (FParser.PeekNext = ')');
  end;

begin
  (* Make sure we are where we think we are *)
  if FParser.Current <> '(' then
    raise Exception.Create('Invalid state: expected current position to be (');

  FParser.Next;
  if FParser.Current <> '*' then
    raise Exception.Create('Invalid state: expected current position to be *');

  while (not FParser.IsEof) and (not IsEndOfAnsiComment) do
    HandleMultilineComment;

  if not FParser.IsEof then
  begin
    { read the closing *) part of the comment }
    FParser.Next;
    FParser.Next;
  end;

  WriteOut(tsComment);
end;  { HandleAnsiC }

procedure TPasFormatter.HandleMultilineComment;
begin
  if FParser.IsEoln then
  begin
    { print accumulated comment so far }
    if not FParser.IsEmptyToken then
    begin
      WriteOut(tsComment);
    end;

    { print CRLF }
    HandleCRLF;
  end
  else
  begin
    { carry on }
    FParser.Next;
  end;
end;

{
  Handles Borland style comments, i.e. with curly braces.
}
procedure TPasFormatter.HandleBorC;
begin
  if FParser.Current = '{' then
  begin
    while (not FParser.IsEof) and (FParser.Current <> '}') do
      HandleMultilineComment;

    (* read the closing } part of the comment *)
    if not FParser.IsEof then
      FParser.Next;

    WriteOut(tsComment);
  end;
end;  { HandleBorC }

procedure TPasFormatter.HandleCRLF;
begin
  if (FParser.Current = #13) and (FParser.PeekNext = #10) then
  begin
    FParser.Next;
    FParser.Next;
    WriteOut(tsCRLF);
  end
  else if (FParser.Current in [#13, #10]) then
  begin
    FParser.Next;
    WriteOut(tsCRLF);
  end;
end;  { HandleCRLF }

procedure TPasFormatter.HandleSlashesC;
begin
  while (not FParser.IsEof) and (not FParser.IsEoln) do
    FParser.Next;

  WriteOut(tsComment);
end;  { HandleSlashesC }

procedure TPasFormatter.HandleString;
begin
  if FParser.Current = #39 then
  begin
    FParser.Next;
    while (not FParser.IsEof) and (FParser.Current <> #39) do
      FParser.Next;

    FParser.Next;
    WriteOut(tsString);
  end;
end;  { HandleString }

procedure TPasFormatter.HandleChar;
begin
  if FParser.Scan(['#'], ['0'..'9']) then
    WriteOut(tsString);
end;

procedure TPasFormatter.HandleHexNumber;
begin
  if FParser.Scan(['$'], ['0'..'9', 'A'..'F', 'a'..'f']) then
    WriteOut(tsNumber);
end;

function TPasFormatter.IsDiffKey(aToken: string): boolean;
var
  First, Last, I, Compare: integer;
  Token: string;
begin
  First := Low(PasDiffKeys);
  Last := High(PasDiffKeys);
  Result := False;
  Token := UpperCase(aToken);
  while First <= Last do
  begin
    I := (First + Last) shr 1;
    Compare := CompareStr(PasDiffKeys[i], Token);
    if Compare = 0 then
    begin
      Result := True;
      break;
    end
    else
    if Compare < 0 then
      First := I + 1
    else
      Last := I - 1;
  end;
end;  { IsDiffKey }

function TPasFormatter.IsDirective(aToken: string): boolean;
var
  First, Last, I, Compare: integer;
  Token: string;
begin
  First := Low(PasDirectives);
  Last := High(PasDirectives);
  Result := False;
  Token := UpperCase(aToken);
  if CompareStr('PROPERTY', Token) = 0 then
    FDiffer := True;
  if IsDiffKey(Token) then
    FDiffer := False;
  while First <= Last do
  begin
    I := (First + Last) shr 1;
    Compare := CompareStr(PasDirectives[i], Token);
    if Compare = 0 then
    begin
      Result := True;
      if FDiffer then
      begin
        Result := False;
        if CompareStr('NAME', Token) = 0 then
          Result := True;
        if CompareStr('RESIDENT', Token) = 0 then
          Result := True;
        if CompareStr('STRINGRESOURCE', Token) = 0 then
          Result := True;
      end;
      break;
    end
    else
    if Compare < 0 then
      First := I + 1
    else
      Last := I - 1;
  end;
end;  { IsDirective }

function TPasFormatter.IsKeyWord(aToken: string): boolean;
var
  First, Last, I, Compare: integer;
  Token: string;
begin
  First := Low(PasKeywords);
  Last := High(PasKeywords);
  Result := False;
  Token := UpperCase(aToken);
  while First <= Last do
  begin
    I := (First + Last) shr 1;
    Compare := CompareStr(PasKeywords[i], Token);
    if Compare = 0 then
    begin
      Result := True;
      break;
    end
    else
    if Compare < 0 then
      First := I + 1
    else
      Last := I - 1;
  end;
end;  { IsKeyWord }

procedure TPasFormatter.HandleIdentifier;
var
  tokenString: string;
  tokenState: TPasTokenState;
begin
  (* cannot start with number but it can contain one *)
  if FParser.Scan(['A'..'Z', 'a'..'z', '_'], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
  begin
    tokenString := FParser.TokenAndMark;

    if IsKeyWord(tokenString) then
    begin
      if IsDirective(tokenString) then
        tokenState := tsDirective
      else
        tokenState := tsKeyWord;
    end
    else
      tokenState := tsIdentifier;

    WriteOut(tokenState, tokenString);
  end;
end;

procedure TPasFormatter.HandleSpace;
begin
  if FParser.Scan([#1..#9, #11, #12, #14..#32], [#1..#9, #11, #12, #14..#32]) then
    WriteOut(tsSpace);
end;

procedure TPasFormatter.HandleNumber;
begin
  if FParser.Scan(['0'..'9'], ['0'..'9', '.', 'e', 'E']) then
    WriteOut(tsNumber);
end;

procedure TPasFormatter.HandleSymbol;
begin
  if (FParser.Current = '/') and (FParser.PeekNext = '/') then
    HandleSlashesC
  else if (FParser.Current = '(') and (FParser.PeekNext = '*') then
    HandleAnsiC
  else if (FParser.Current in ['!', '"', '%', '&', '('..'/', ':'..'@',
    '['..'^', '`', '~']) then
  begin
    FParser.Next;
    WriteOut(tsSymbol);
  end;
end;

procedure _WriteOut(OutStream: TStream; const str: string);
var
  b, Buf: PChar;
begin
  if Length(str) > 0 then
  begin
    GetMem(Buf, Length(str) + 1);
    StrCopy(Buf, PChar(str));
    b := Buf;
    OutStream.Write(Buf^, Length(str));
    FreeMem(b);
  end;
end;

procedure _WriteOutLn(OutStream: TStream; const str: string);
begin
  _WriteOut(OutStream, str);
  _WriteOut(OutStream, LineEnding);
end;

procedure TPasFormatter.WriteOut(tokenState: TPasTokenState; const str: string);
begin
  _WriteOut(FOutStream, FFormatter.FormatToken(str, tokenState));
end;

procedure TPasFormatter.WriteOut(tokenState: TPasTokenstate);
begin
  WriteOut(tokenState, FParser.TokenAndMark);
end;

(* Pascal to RTF converter *)

function TPasToRTF.FormatToken(const NewToken: string;
  TokenState: TPasTokenState): string;
var
  escapedToken: string;
begin
  escapedToken := SetSpecial(NewToken);
  case TokenState of
    tsCRLF:
      FormatToken := '\par' + escapedToken;
    tsDirective, tsKeyword:
      FormatToken := '\b ' + escapedToken + '\b0 ';
    tsComment:
      FormatToken := '\cf1\i ' + escapedToken + '\cf0\i0 ';
    else
      FormatToken := escapedToken;
  end;
end;

function TPasToRTF.SetSpecial(const str: string): string;
var
  i: integer;
begin
  Result := '';
  for i := 1 to Length(str) do
    case str[i] of
      '\', '{', '}': Result := Result + '\' + str[i];
      else
        Result := Result + str[i];
    end;
end;

procedure TPasToRTF.WriteFooter(OutStream: TStream);
begin
  _WriteOutLn(OutStream, '');
  _WriteOutLn(OutStream, '\par}');
end;

procedure TPasToRTF.WriteHeader(OutStream: TStream);
begin
  _WriteOutLn(OutStream, '{\rtf1\ansi\ansicpg1253\deff0\deflang1032');
  _WriteOutLn(OutStream, '');
  _WriteOutLn(OutStream, '{\fonttbl');
  _WriteOutLn(OutStream, '{\f0\fcourier Courier New Greek;}');
  _WriteOutLn(OutStream, '}');
  _WriteOutLn(OutStream, '');
  _WriteOutLn(OutStream, '{\colortbl ;\red0\green0\blue128;}');
  _WriteOutLn(OutStream, '');
  _WriteOutLn(OutStream, '\pard\plain \li120 \fs20');
end;

(* Pascal To HTML Converter *)

function TPasToHTML.FormatToken(const NewToken: string;
  TokenState: TPasTokenState): string;
var
  escapedToken: string;
begin
  escapedToken := SetSpecial(NewToken);
  case TokenState of
    tsCRLF:
      FormatToken := '<BR>' + escapedToken;
    tsDirective, tsKeyWord:
      FormatToken := '<B>' + escapedToken + '</B>';
    tsComment:
      FormatToken := '<FONT COLOR=#000080><I>' + escapedToken + '</I></FONT>';
    tsUnknown:
      FormatToken := '<FONT COLOR=#FF0000><B>' + escapedToken + '</B></FONT>';
    else
      FormatToken := escapedToken;
  end;
end;

function TPasToHTML.SetSpecial(const str: string): string;
var
  i: integer;
begin
  Result := '';
  for i := 1 to Length(str) do
    case str[i] of
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '&': Result := Result + '&amp;';
      '"': Result := Result + '&quot;';
      ' ':
        if (i < Length(str)) and (str[i + 1] = ' ') then
          Result := Result + '&nbsp;'
        else
          Result := Result + ' ';
      else
        Result := Result + str[i];
    end;
end;

procedure TPasToHTML.WriteFooter(OutStream: TStream);
begin
  _WriteOutLn(OutStream, '</TT></BODY>');
  _WriteOutLn(OutStream, '</HTML>');
end;

procedure TPasToHTML.WriteHeader(OutStream: TStream);
begin
  _WriteOutLn(OutStream, '<HTML>');
  _WriteOutLn(OutStream, '<HEAD>');
  _WriteOutLn(OutStream, '<TITLE></TITLE>');
  _WriteOutLn(OutStream, '</HEAD>');
  _WriteOutLn(OutStream, '<BODY><TT>');
end;

end.
