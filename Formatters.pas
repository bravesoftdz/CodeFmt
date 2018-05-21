unit Formatters;

{$mode delphi}

interface

uses
  Classes, SysUtils, TokenTypes;

type
  TFormatterBase = class
  private
    FOutputStream: TStream;
  protected
    property OutputStream: TStream read FOutputStream;
    procedure Write(const str: string);
    procedure WriteLn(const str: string);
  public
    constructor Create(OutputStream: TStream);
    procedure WriteHeader; virtual; abstract;
    procedure WriteFooter; virtual; abstract;
    procedure WriteToken(const NewToken: string; TokenState: TTokenType); virtual; abstract;
  end;

implementation

procedure TFormatterBase.Write(const str: string);
var
  b, Buf: PChar;
begin
  if Length(str) > 0 then
  begin
    GetMem(Buf, Length(str) + 1);
    StrCopy(Buf, PChar(str));
    b := Buf;
    OutputStream.Write(Buf^, Length(str));
    FreeMem(b);
  end;
end;

procedure TFormatterBase.WriteLn(const str: string);
begin
  Write(str);
  Write(LineEnding);
end;

constructor TFormatterBase.Create(OutputStream: TStream);
begin
  FOutputStream := OutputStream;
end;

end.
