unit CppConv;

{$MODE Delphi}

interface

uses SysUtils, Classes, Parser, Formatters, LexerBase;

type
  TCppFormatter = class(TLexBase)
  private
    procedure HandleString;
    procedure HandleIdentifier;
    procedure HandlePreProcessorDirective;
    procedure HandleSymbol;
  protected
    procedure Scan; override;
  end;

implementation

const
  CppKeyWords: array [0..59] of string =
    ('_cs', '_ds', '_es', '_export', '_fastcall',
    '_loadds', '_saveregs', '_seg', '_ss', 'asm',
    'auto', 'break', 'case', 'cdecl', 'char',
    'class', 'const', 'continue', 'default', 'delete',
    'do', 'double', 'else', 'enum', 'extern',
    'far', 'float', 'for', 'friend', 'goto',
    'huge', 'if', 'inline', 'int', 'interrupt',
    'long', 'near', 'new', 'operator', 'pascal',
    'private', 'protected', 'public', 'register', 'return',
    'short', 'signed', 'sizeof', 'static', 'struct',
    'switch', 'template', 'this', 'typedef', 'union',
    'unsigned', 'virtual', 'void', 'volatile', 'while');

procedure TCppFormatter.Scan;
begin
  HandleCRLF(Parser, Formatter);
  HandleSpace(Parser, Formatter);
  HandleSlashesComment(Parser, Formatter);
  HandleString;
  HandleIdentifier;
  HandlePreProcessorDirective;
  HandleSymbol;
end;

procedure TCppFormatter.HandleString;
begin
  if Parser.Current = '"' then
  begin
    Parser.Next;
    while (not Parser.IsEof) and (Parser.Current <> '"') do
      Parser.Next;

    Parser.Next;
    WriteOut(ttString);
  end;
end;

function ArrayContains(hay: array of string; needle: string): boolean;
var
  i: integer;
begin
  Result := False;

  for i := Low(hay) to High(hay) do
    if hay[i] = needle then
    begin
      Result := True;
      break;
    end;
end;

procedure TCppFormatter.HandleIdentifier;
var
  token: string;
  tokenType: TTokenType;
begin
  if Parser.Scan(['a'..'z', 'A'..'Z'], ['a'..'z', 'A'..'Z', '_']) then
  begin
    token := Parser.TokenAndMark;

    if ArrayContains(CppKeyWords, token) then
      tokenType := ttKeyWord
    else
      tokenType := ttIdentifier;

    WriteOut(tokenType, token);
  end;
end;

procedure TCppFormatter.HandlePreProcessorDirective;
begin
  if Parser.Current = '#' then
  begin
    while (not Parser.IsEof) and (not Parser.IsEoln) do
      Parser.Next;

    WriteOut(ttPreProcessor);
  end;
end;

procedure TCppFormatter.HandleSymbol;
begin
  if Parser.Current in ['(', ')', ';', '{', '}', '[', ']'] then
  begin
    Parser.Next;
    WriteOut(ttSymbol);
  end;
end;

end.
