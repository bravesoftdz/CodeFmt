unit LexerBase;

{$mode delphi}

interface

uses
  Classes, SysUtils, StreamTokenizer, Formatters, TokenTypes;

type
  TLexerBase = class
  private
    FFormatter: TFormatterBase;
    FStreamTokenizer: TStreamTokenizer;
  protected
    procedure WriteOut(tokenType: TTokenType; const str: string); overload;
    procedure WriteOut(tokenType: TTokenType); overload;
    procedure Scan; virtual;
    property Formatter: TFormatterBase read FFormatter;
    property StreamTokenizer: TStreamTokenizer read FStreamTokenizer;
  public
    constructor Create(Formatter: TFormatterBase);
    procedure FormatStream(InputStream: TStream);
  end;

procedure HandleCRLF(StreamTokenizer: TStreamTokenizer; Formatter: TFormatterBase);
procedure HandleSpace(StreamTokenizer: TStreamTokenizer; Formatter: TFormatterBase);
procedure HandleSlashesComment(StreamTokenizer: TStreamTokenizer; Formatter: TFormatterBase);
procedure HandleLineComment(StreamTokenizer: TStreamTokenizer; Formatter: TFormatterBase; CommentMark: string);

implementation

constructor TLexerBase.Create(Formatter: TFormatterBase);
begin
  FFormatter := Formatter;
end;

procedure TLexerBase.FormatStream(InputStream: TStream);
var
  oldPosition: integer;
begin
  FStreamTokenizer := TStreamTokenizer.Create(InputStream);
  try
    FFormatter.WriteHeader;

    while not FStreamTokenizer.IsEof do
    begin
      oldPosition := FStreamTokenizer.Position;

      Scan;

      if oldPosition = FStreamTokenizer.Position then
      begin
        (* unexpected token, read one char and print it out immediately *)
        FStreamTokenizer.Next;
        WriteOut(ttUnknown);
      end;
    end;

    FFormatter.WriteFooter;
  finally
    FStreamTokenizer.Free;
  end;
end;

procedure TLexerBase.WriteOut(tokenType: TTokenType; const str: string);
begin
  FFormatter.WriteToken(str, tokenType);
end;

procedure TLexerBase.WriteOut(tokenType: TTokenType);
begin
  WriteOut(tokenType, FStreamTokenizer.TokenAndMark);
end;

procedure TLexerBase.Scan;
begin

end;

procedure HandleCRLF(StreamTokenizer: TStreamTokenizer; Formatter: TFormatterBase);
begin
  if (StreamTokenizer.Current = #13) and (StreamTokenizer.PeekNext = #10) then
  begin
    StreamTokenizer.Next;
    StreamTokenizer.Next;
    Formatter.WriteToken(StreamTokenizer.TokenAndMark, ttCRLF);
  end
  else if (StreamTokenizer.Current in [#13, #10]) then
  begin
    StreamTokenizer.Next;
    Formatter.WriteToken(StreamTokenizer.TokenAndMark, ttCRLF);
  end;
end;

procedure HandleSpace(StreamTokenizer: TStreamTokenizer; Formatter: TFormatterBase);
begin
  if StreamTokenizer.Scan([#1..#9, #11, #12, #14..#32], [#1..#9, #11, #12, #14..#32]) then
    Formatter.WriteToken(StreamTokenizer.TokenAndMark, ttSpace);
end;

procedure HandleSlashesComment(StreamTokenizer: TStreamTokenizer; Formatter: TFormatterBase);
begin
  HandleLineComment(StreamTokenizer, Formatter, '//');
end;

procedure HandleLineComment(StreamTokenizer: TStreamTokenizer; Formatter: TFormatterBase; CommentMark: string);
begin
  if StreamTokenizer.PeekLength(Length(CommentMark)) = CommentMark then
  begin
    while (not StreamTokenizer.IsEof) and (not StreamTokenizer.IsEoln) do
      StreamTokenizer.Next;

    Formatter.WriteToken(StreamTokenizer.TokenAndMark, ttComment);
  end;
end;

end.
