unit LexerBase;

{$mode delphi}

interface

uses
  Classes, SysUtils, Parser, Formatters;

type
  TLexBase = class
  private
    FFormatter: TFormatterBase;
    FParser: TParser;
  protected
    procedure WriteOut(tokenType: TTokenType; const str: string); overload;
    procedure WriteOut(tokenType: TTokenType); overload;
    procedure Scan; virtual;
    property Formatter: TFormatterBase read FFormatter;
    property Parser: TParser read FParser;
  public
    constructor Create(Formatter: TFormatterBase);
    procedure FormatStream(InStream: TStream);
  end;

procedure HandleCRLF(Parser: TParser; Formatter: TFormatterBase);
procedure HandleSpace(Parser: TParser; Formatter: TFormatterBase);
procedure HandleSlashesComment(Parser: TParser; Formatter: TFormatterBase);
procedure HandleLineComment(Parser: TParser; Formatter: TFormatterBase; CommentMark: string);

implementation

constructor TLexBase.Create(Formatter: TFormatterBase);
begin
  FFormatter := Formatter;
end;

procedure TLexBase.FormatStream(InStream: TStream);
var
  oldPosition: integer;
begin
  FParser := TParser.Create(InStream);
  try
    FFormatter.WriteHeader;

    while not FParser.IsEof do
    begin
      oldPosition := FParser.Position;

      Scan;

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

procedure TLexBase.WriteOut(tokenType: TTokenType; const str: string);
begin
  FFormatter.WriteToken(str, tokenType);
end;

procedure TLexBase.WriteOut(tokenType: TTokenType);
begin
  WriteOut(tokenType, FParser.TokenAndMark);
end;

procedure TLexBase.Scan;
begin

end;

procedure HandleCRLF(Parser: TParser; Formatter: TFormatterBase);
begin
  if (Parser.Current = #13) and (Parser.PeekNext = #10) then
  begin
    Parser.Next;
    Parser.Next;
    Formatter.WriteToken(Parser.TokenAndMark, ttCRLF);
  end
  else if (Parser.Current in [#13, #10]) then
  begin
    Parser.Next;
    Formatter.WriteToken(Parser.TokenAndMark, ttCRLF);
  end;
end;

procedure HandleSpace(Parser: TParser; Formatter: TFormatterBase);
begin
  if Parser.Scan([#1..#9, #11, #12, #14..#32], [#1..#9, #11, #12, #14..#32]) then
    Formatter.WriteToken(Parser.TokenAndMark, ttSpace);
end;

procedure HandleSlashesComment(Parser: TParser; Formatter: TFormatterBase);
begin
  HandleLineComment(Parser, Formatter, '//');
end;

procedure HandleLineComment(Parser: TParser; Formatter: TFormatterBase; CommentMark: string);
begin
  if Parser.PeekLength(Length(CommentMark)) = CommentMark then
  begin
    while (not Parser.IsEof) and (not Parser.IsEoln) do
      Parser.Next;

    Formatter.WriteToken(Parser.TokenAndMark, ttComment);
  end;
end;

end.
