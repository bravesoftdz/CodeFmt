unit LexerBase;

{$mode delphi}

interface

uses
  Classes, SysUtils, StreamTokenizer, TokenTypes;

type
  TLexerTokenFound = procedure(const Token: string; const TokenType: TTokenType) of object;

  TLexerBase = class
  private
    FTokenFound: TLexerTokenFound;
    FStreamTokenizer: TStreamTokenizer;
  protected
    procedure CurrentTokenFound(const TokenType: TTokenType);
    procedure Scan; virtual;
    property TokenFound: TLexerTokenFound read FTokenFound;
    property StreamTokenizer: TStreamTokenizer read FStreamTokenizer;
  public
    constructor Create(TokenFound: TLexerTokenFound);
    procedure FormatStream(InputStream: TStream);
  end;

procedure HandleCRLF(StreamTokenizer: TStreamTokenizer; TokenFound: TLexerTokenFound);
procedure HandleSpace(StreamTokenizer: TStreamTokenizer; TokenFound: TLexerTokenFound);
procedure HandleSlashesComment(StreamTokenizer: TStreamTokenizer; TokenFound: TLexerTokenFound);
procedure HandleLineComment(StreamTokenizer: TStreamTokenizer; TokenFound: TLexerTokenFound; CommentMark: string);

implementation

constructor TLexerBase.Create(TokenFound: TLexerTokenFound);
begin
  FTokenFound := TokenFound;
end;

procedure TLexerBase.FormatStream(InputStream: TStream);
var
  oldPosition: integer;
begin
  FStreamTokenizer := TStreamTokenizer.Create(InputStream);
  try
    while not FStreamTokenizer.IsEof do
    begin
      { capture current position of the stream }
      oldPosition := FStreamTokenizer.Position;

      { scan next token }
      Scan;

      { if nothing was scanned... }
      if oldPosition = FStreamTokenizer.Position then
      begin
        (* unexpected token, read one char and print it out immediately *)
        FStreamTokenizer.Next;
        CurrentTokenFound(ttUnknown);
      end;
    end;
  finally
    FStreamTokenizer.Free;
  end;
end;

procedure TLexerBase.CurrentTokenFound(const TokenType: TTokenType);
begin
  TokenFound(FStreamTokenizer.TokenAndMark, TokenType);
end;

procedure TLexerBase.Scan;
begin

end;

procedure HandleCRLF(StreamTokenizer: TStreamTokenizer; TokenFound: TLexerTokenFound);
begin
  if (StreamTokenizer.Current = #13) and (StreamTokenizer.PeekNext = #10) then
  begin
    StreamTokenizer.Next;
    StreamTokenizer.Next;
    TokenFound(StreamTokenizer.TokenAndMark, ttCRLF);
  end
  else if (StreamTokenizer.Current in [#13, #10]) then
  begin
    StreamTokenizer.Next;
    TokenFound(StreamTokenizer.TokenAndMark, ttCRLF);
  end;
end;

procedure HandleSpace(StreamTokenizer: TStreamTokenizer; TokenFound: TLexerTokenFound);
begin
  if StreamTokenizer.Scan([#1..#9, #11, #12, #14..#32], [#1..#9, #11, #12, #14..#32]) then
    TokenFound(StreamTokenizer.TokenAndMark, ttSpace);
end;

procedure HandleSlashesComment(StreamTokenizer: TStreamTokenizer; TokenFound: TLexerTokenFound);
begin
  HandleLineComment(StreamTokenizer, TokenFound, '//');
end;

procedure HandleLineComment(StreamTokenizer: TStreamTokenizer; TokenFound: TLexerTokenFound; CommentMark: string);
begin
  if StreamTokenizer.PeekLength(Length(CommentMark)) = CommentMark then
  begin
    while (not StreamTokenizer.IsEof) and (not StreamTokenizer.IsEoln) do
      StreamTokenizer.Next;

    TokenFound(StreamTokenizer.TokenAndMark, ttComment);
  end;
end;

end.
