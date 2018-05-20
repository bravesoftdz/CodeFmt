unit PasConv;

{$MODE Delphi}

interface

uses SysUtils, Classes, Parser, Formatters, LexerBase;

type
  TPasFormatter = class(TLexBase)
  private
    procedure HandleAnsiComments;
    procedure HandleBorC;
    procedure HandleString;
    procedure HandleIdentifier;
    procedure HandleNumber;
    procedure HandleSymbol;
    procedure HandleMultilineComment;
    procedure HandleChar;
    procedure HandleHexNumber;
    function IsDiffKey(aToken: string): boolean;
    function IsDirective(aToken: string): boolean;
    function IsKeyword(aToken: string): boolean;
  protected
    procedure Scan; override;
  end;

implementation

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

procedure TPasFormatter.Scan;
begin
  HandleCRLF(Parser, Formatter);
  HandleSpace(Parser, Formatter);
  HandleSlashesComment(Parser, Formatter);
  HandleAnsiComments;
  HandleIdentifier;
  HandleNumber;
  HandleBorC;
  HandleSymbol;
  HandleString;
  HandleChar;
  HandleHexNumber;
end;

(*
  Handles Ansi style comments, i.e. with parenthesis and stars.
*)
procedure TPasFormatter.HandleAnsiComments;

  function IsEndOfAnsiComment: boolean;
  begin
    IsEndOfAnsiComment := (Parser.Current = '*') and (Parser.PeekNext = ')');
  end;

begin
  if (Parser.Current = '(') and (Parser.PeekNext = '*') then
  begin
    { read the '(' and the '*' }
    Parser.Next;
    Parser.Next;

    while (not Parser.IsEof) and (not IsEndOfAnsiComment) do
      HandleMultilineComment;

    if not Parser.IsEof then
    begin
      { read the closing *) part of the comment }
      Parser.Next;
      Parser.Next;
    end;

    WriteOut(ttComment);
  end;
end;

procedure TPasFormatter.HandleMultilineComment;
begin
  if Parser.IsEoln then
  begin
    { print accumulated comment so far }
    if not Parser.IsEmptyToken then
    begin
      WriteOut(ttComment);
    end;

    { print CRLF }
    HandleCRLF(Parser, Formatter);
  end
  else
  begin
    { carry on }
    Parser.Next;
  end;
end;

{
  Handles Borland style comments, i.e. with curly braces.
}
procedure TPasFormatter.HandleBorC;
begin
  if Parser.Current = '{' then
  begin
    while (not Parser.IsEof) and (Parser.Current <> '}') do
      HandleMultilineComment;

    (* read the closing } part of the comment *)
    if not Parser.IsEof then
      Parser.Next;

    WriteOut(ttComment);
  end;
end;

procedure TPasFormatter.HandleString;
begin
  if Parser.Current = #39 then
  begin
    Parser.Next;
    while (not Parser.IsEof) and (Parser.Current <> #39) do
      Parser.Next;

    Parser.Next;
    WriteOut(ttString);
  end;
end;  { HandleString }

procedure TPasFormatter.HandleChar;
begin
  if Parser.Scan(['#'], ['0'..'9']) then
    WriteOut(ttString);
end;

procedure TPasFormatter.HandleHexNumber;
begin
  if Parser.Scan(['$'], ['0'..'9', 'A'..'F', 'a'..'f']) then
    WriteOut(ttNumber);
end;

function BinarySearch(hay: array of string; needle: string): boolean;
var
  First, Last, I, Compare: integer;
  Token: string;
begin
  First := Low(hay);
  Last := High(hay);
  Result := False;
  Token := UpperCase(needle);
  while First <= Last do
  begin
    I := (First + Last) shr 1;
    Compare := CompareStr(hay[i], Token);
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
end;

function TPasFormatter.IsDiffKey(aToken: string): boolean;
begin
  Result := BinarySearch(PasDiffKeys, aToken);
end;  { IsDiffKey }

function TPasFormatter.IsDirective(aToken: string): boolean;
var
  First, Last, I, Compare: integer;
  Token: string;
  FDiffer: boolean;
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
end;

function TPasFormatter.IsKeyword(aToken: string): boolean;
begin
  Result := BinarySearch(PasKeywords, aToken);
end;

procedure TPasFormatter.HandleIdentifier;
var
  tokenString: string;
  tokenType: TTokenType;
begin
  (* cannot start with number but it can contain one *)
  if Parser.Scan(['A'..'Z', 'a'..'z', '_'], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
  begin
    tokenString := Parser.TokenAndMark;

    if IsKeyword(tokenString) then
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

procedure TPasFormatter.HandleNumber;
begin
  if Parser.Scan(['0'..'9'], ['0'..'9', '.', 'e', 'E']) then
    WriteOut(ttNumber);
end;

procedure TPasFormatter.HandleSymbol;
begin
  if (Parser.Current in ['!', '"', '%', '&', '('..'/', ':'..'@',
    '['..'^', '`', '~']) then
  begin
    Parser.Next;
    WriteOut(ttSymbol);
  end;
end;

end.
