unit StreamTokenizer;

{$mode delphi}

interface

uses
  Classes, SysUtils;

type
  TStreamTokenizer = class
  private
    FReadBuf: PChar;
    FCurrent: PChar;
    FMark: PChar;
    FPosition: integer;
    FReadBufSize: integer;
    function GetCurrent: char;
    procedure Mark;
    function Token: string;
  public
    constructor Create(InputStream: TStream);
    destructor Destroy; override;
    procedure Next;
    function TokenAndMark: string;
    function PeekNext: char;
    function PeekLength(Count: integer): string;
    function IsEof: boolean;
    function IsEoln: boolean;
    function IsEmptyToken: boolean;
    function Scan(firstChar, validChars: TSysCharSet): boolean;

    { Gets the character at the current position of the reader. }
    property Current: char read GetCurrent;
    property Position: integer read FPosition;
  end;

implementation

constructor TStreamTokenizer.Create(InputStream: TStream);
var
  FReadBuf: PChar;
begin
  GetMem(FReadBuf, InputStream.Size + 1);
  FReadBufSize := InputStream.Read(FReadBuf^, InputStream.Size);
  FReadBuf[FReadBufSize] := #0;
  FCurrent := FReadBuf;
  FPosition := 0;
  Mark;
end;

destructor TStreamTokenizer.Destroy;
begin
  FreeMem(FReadBuf);
end;

function TStreamTokenizer.GetCurrent: char;
begin
  GetCurrent := FCurrent^;
end;

procedure TStreamTokenizer.Mark;
begin
  FMark := FCurrent;
end;

procedure TStreamTokenizer.Next;
begin
  Inc(FCurrent);
  Inc(FPosition);
end;

function TStreamTokenizer.Token: string;
var
  tokenLen: integer;
  tokenString: string;
begin
  tokenLen := FCurrent - FMark;
  SetString(tokenString, FMark, tokenLen);
  Token := tokenString;
end;

function TStreamTokenizer.TokenAndMark: string;
begin
  TokenAndMark := Token;
  Mark;
end;

function TStreamTokenizer.PeekNext: char;
begin
  if IsEof then
    PeekNext := #0
  else
    PeekNext := (FCurrent + 1)^;
end;

function TStreamTokenizer.IsEof: boolean;
begin
  IsEof := Current = #0;
end;

function TStreamTokenizer.IsEmptyToken: boolean;
begin
  IsEmptyToken := FCurrent = FMark;
end;

function TStreamTokenizer.IsEoln: boolean;
begin
  IsEoln := Current in [#13, #10];
end;

function TStreamTokenizer.Scan(firstChar: TSysCharSet; validChars: TSysCharSet): boolean;
begin
  if Current in firstChar then
  begin
    Next;
    while (not IsEof) and (Current in validChars) do
      Next;

    Scan := True;
  end
  else
    Scan := False;
end;

function TStreamTokenizer.PeekLength(Count: integer): string;
var
  buffer: string;
  i: integer;
begin
  buffer := '';
  i := 0;
  while (i < count) and ((FCurrent + i)^ <> #0) do
  begin
    buffer := buffer + (FCurrent + i)^;
    Inc(i);
  end;

  Result := buffer;
end;

end.
