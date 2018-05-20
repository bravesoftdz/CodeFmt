unit CppConv;

{$MODE Delphi}

interface

uses SysUtils, Classes, Parser, Formatters, LexerBase;

type
  TCppFormatter = class(TLexBase)
  private
    procedure HandleString;
    procedure HandleIdentifier;
  protected
    procedure Scan; override;
  end;

procedure CppToHTMLFile(const CppFile, HTMLFile: string);
procedure CppToRTFFile(const CppFile, RTFFile: string);
procedure CppToHTMLStream(inputStream, outputStream: TStream);
procedure CppToRTFStream(inputStream, outputStream: TStream);

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

procedure CppToHTMLStream(inputStream, outputStream: TStream);
var
  htmlFormatter: THTMLFormatter;
  cpp: TCppFormatter;
begin
  htmlFormatter := THTMLFormatter.Create(outputStream);
  try
    cpp := TCppFormatter.Create(htmlFormatter);
    try
      cpp.FormatStream(inputStream);
    finally
      cpp.Free;
    end;
  finally
    htmlFormatter.Free;
  end;
end;

procedure CppToRTFStream(inputStream, outputStream: TStream);
var
  rtfFormatter: TRTFFormatter;
  cpp: TCppFormatter;
begin
  rtfFormatter := TRTFFormatter.Create(outputStream);
  try
    cpp := TCppFormatter.Create(rtfFormatter);
    try
      cpp.FormatStream(inputStream);
    finally
      cpp.Free;
    end;
  finally
    rtfFormatter.Free;
  end;
end;

procedure CppToHTMLFile(const CppFile, HTMLFile: string);
var
  stream1, stream2: TFileStream;
begin
  stream1 := TFileStream.Create(CppFile, fmOpenRead);
  try
    stream2 := TFileStream.Create(HTMLFile, fmCreate);
    try
      CppToHTMLStream(stream1, stream2);
    finally
      stream2.Free;
    end;
  finally
    stream1.Free;
  end;
end;

procedure CppToRTFFile(const CppFile, RTFFile: string);
var
  stream1, stream2: TFileStream;
begin
  stream1 := TFileStream.Create(CppFile, fmOpenRead);
  try
    stream2 := TFileStream.Create(RTFFile, fmCreate);
    try
      CppToRTFStream(stream1, stream2);
    finally
      stream2.Free;
    end;
  finally
    stream1.Free;
  end;
end;

procedure TCppFormatter.Scan;
begin
  HandleCRLF(Parser, Formatter);
  HandleSpace(Parser, Formatter);
  HandleString;
  HandleIdentifier;
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

end.
