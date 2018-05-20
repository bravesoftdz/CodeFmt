unit Parser;

{$mode delphi}

interface

uses
  Classes, SysUtils;

type
  TParser = class
  private
    FReadBuf: PChar;
    FCurrent: PChar;
    FMark: PChar;
    FPosition: integer;
    function GetCurrent: char;
    procedure Mark;
    function Token: string;
  public
    constructor Create(InStream: TStream);
    destructor Destroy; override;
    procedure Next;
    function TokenAndMark: string;
    function PeekNext: char;
    function IsEof: boolean;
    function IsEoln: boolean;
    function IsEmptyToken: boolean;
    function Scan(firstChar, validChars: TSysCharSet): boolean;

    { Gets the character at the current position of the reader. }
    property Current: char read GetCurrent;
    property Position: integer read FPosition;
  end;

implementation

constructor TParser.Create(InStream: TStream);
var
  FReadBuf: PChar;
  i: integer;
begin
  GetMem(FReadBuf, InStream.Size + 1);
  i := InStream.Read(FReadBuf^, InStream.Size);
  FReadBuf[i] := #0;
  FCurrent := FReadBuf;
  FPosition := 0;
  Mark;
end;

destructor TParser.Destroy;
begin
  FreeMem(FReadBuf);
end;

function TParser.GetCurrent: char;
begin
  GetCurrent := FCurrent^;
end;

procedure TParser.Mark;
begin
  FMark := FCurrent;
end;

procedure TParser.Next;
begin
  Inc(FCurrent);
  Inc(FPosition);
end;

function TParser.Token: string;
var
  tokenLen: integer;
  tokenString: string;
begin
  tokenLen := FCurrent - FMark;
  SetString(tokenString, FMark, tokenLen);
  Token := tokenString;
end;

function TParser.TokenAndMark: string;
begin
  TokenAndMark := Token;
  Mark;
end;

function TParser.PeekNext: char;
begin
  if IsEof then
    PeekNext := #0
  else
    PeekNext := (FCurrent + 1)^;
end;

function TParser.IsEof: boolean;
begin
  IsEof := Current = #0;
end;

function TParser.IsEmptyToken: boolean;
begin
  IsEmptyToken := FCurrent = FMark;
end;

function TParser.IsEoln: boolean;
begin
  IsEoln := Current in [#13, #10];
end;

function TParser.Scan(firstChar: TSysCharSet; validChars: TSysCharSet): boolean;
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

end.
