unit PasConv;

{$MODE Delphi}

interface

uses SysUtils, Classes, Parser, Formatters;

type
  TPasFormatter = class
  private
    FFormatter: TFormatterBase;
    FDiffer: boolean;
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
    procedure WriteOut(tokenType: TTokenType; const str: string); overload;
    procedure WriteOut(tokenType: TTokenType); overload;
  public
    constructor Create(Formatter: TFormatterBase);
    procedure FormatStream(InStream: TStream);
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
procedure PasToHTMLStream(inputStream, outputStream: TStream);
procedure PasToRTFStream(inputStream, outputStream: TStream);

implementation

procedure PasToHTMLStream(inputStream, outputStream: TStream);
var
  pascalToHtmlFormatter: TPasToHTML;
  p: TPasFormatter;
begin
  pascalToHtmlFormatter := TPasToHTML.Create(outputStream);
  try
    p := TPasFormatter.Create(pascalToHtmlFormatter);
    try
      p.FormatStream(inputStream);
    finally
      p.Free;
    end;
  finally
    pascalToHtmlFormatter.Free;
  end;
end;

procedure PasToRTFStream(inputStream, outputStream: TStream);
var
  pascalToRtfFormatter: TPasToRTF;
  p: TPasFormatter;
begin
  pascalToRtfFormatter := TPasToRTF.Create(outputStream);
  try
    p := TPasFormatter.Create(pascalToRtfFormatter);
    try
      p.FormatStream(inputStream);
    finally
      p.Free;
    end;
  finally
    pascalToRtfFormatter.Free;
  end;
end;

procedure PasToHTMLFile(const PasFile, HTMLFile: string);
var
  inputStream, outputStream: TFileStream;
begin
  inputStream := TFileStream.Create(PasFile, fmOpenRead);
  try
    outputStream := TFileStream.Create(HTMLFile, fmCreate);
    try
      PasToHTMLStream(inputStream, outputStream);
    finally
      outputStream.Free;
    end;
  finally
    inputStream.Free;
  end;
end;

procedure PasToRTFFile(const PasFile, RTFFile: string);
var
  inputStream, outputStream: TFileStream;
begin
  inputStream := TFileStream.Create(PasFile, fmOpenRead);
  try
    outputStream := TFileStream.Create(RTFFile, fmCreate);
    try
      PasToRTFStream(inputStream, outputStream);
    finally
      outputStream.Free;
    end;
  finally
    inputStream.Free;
  end;
end;

constructor TPasFormatter.Create(Formatter: TFormatterBase);
begin
  FFormatter := Formatter;
end;

procedure TPasFormatter.FormatStream(InStream: TStream);
var
  oldPosition: integer;
begin
  FParser := TParser.Create(InStream);

  try
    FFormatter.WriteHeader;

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
        WriteOut(ttUnknown);
      end;

    end;

    FFormatter.WriteFooter;
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

  WriteOut(ttComment);
end;  { HandleAnsiC }

procedure TPasFormatter.HandleMultilineComment;
begin
  if FParser.IsEoln then
  begin
    { print accumulated comment so far }
    if not FParser.IsEmptyToken then
    begin
      WriteOut(ttComment);
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

    WriteOut(ttComment);
  end;
end;  { HandleBorC }

procedure TPasFormatter.HandleCRLF;
begin
  if (FParser.Current = #13) and (FParser.PeekNext = #10) then
  begin
    FParser.Next;
    FParser.Next;
    WriteOut(ttCRLF);
  end
  else if (FParser.Current in [#13, #10]) then
  begin
    FParser.Next;
    WriteOut(ttCRLF);
  end;
end;  { HandleCRLF }

procedure TPasFormatter.HandleSlashesC;
begin
  while (not FParser.IsEof) and (not FParser.IsEoln) do
    FParser.Next;

  WriteOut(ttComment);
end;  { HandleSlashesC }

procedure TPasFormatter.HandleString;
begin
  if FParser.Current = #39 then
  begin
    FParser.Next;
    while (not FParser.IsEof) and (FParser.Current <> #39) do
      FParser.Next;

    FParser.Next;
    WriteOut(ttString);
  end;
end;  { HandleString }

procedure TPasFormatter.HandleChar;
begin
  if FParser.Scan(['#'], ['0'..'9']) then
    WriteOut(ttString);
end;

procedure TPasFormatter.HandleHexNumber;
begin
  if FParser.Scan(['$'], ['0'..'9', 'A'..'F', 'a'..'f']) then
    WriteOut(ttNumber);
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
  tokenType: TTokenType;
begin
  (* cannot start with number but it can contain one *)
  if FParser.Scan(['A'..'Z', 'a'..'z', '_'], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
  begin
    tokenString := FParser.TokenAndMark;

    if IsKeyWord(tokenString) then
    begin
      if IsDirective(tokenString) then
        tokenType := ttDirective
      else
        tokenType := ttKeyWord;
    end
    else
      tokenType := ttIdentifier;

    WriteOut(tokenType, tokenString);
  end;
end;

procedure TPasFormatter.HandleSpace;
begin
  if FParser.Scan([#1..#9, #11, #12, #14..#32], [#1..#9, #11, #12, #14..#32]) then
    WriteOut(ttSpace);
end;

procedure TPasFormatter.HandleNumber;
begin
  if FParser.Scan(['0'..'9'], ['0'..'9', '.', 'e', 'E']) then
    WriteOut(ttNumber);
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
    WriteOut(ttSymbol);
  end;
end;


procedure TPasFormatter.WriteOut(tokenType: TTokenType; const str: string);
begin
  FFormatter.WriteToken(str, tokenType);
end;

procedure TPasFormatter.WriteOut(tokenType: TTokenType);
begin
  WriteOut(tokenType, FParser.TokenAndMark);
end;

end.
