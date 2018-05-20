unit EditorConfigLexer;

{$mode delphi}

interface

uses
  Classes, SysUtils, LexerBase;

type
  TEditorConfigLexer = class(TLexBase)
  protected
    procedure Scan; override;
  private
    procedure HandleIdentifier;
    procedure HandleNumber;
    procedure HandleSymbol;
  end;

implementation

uses
  Formatters;

procedure TEditorConfigLexer.Scan;
begin
  HandleCRLF(Parser, Formatter);
  HandleSpace(Parser, Formatter);
  HandleLineComment(Parser, Formatter, '#');
  HandleIdentifier;
  HandleNumber;
  HandleSymbol;
end;

procedure TEditorConfigLexer.HandleIdentifier;
begin
  if Parser.Scan(['a'..'z'], ['a'..'z', '0'..'9', '-', '_']) then
    WriteOut(ttIdentifier);
end;

procedure TEditorConfigLexer.HandleNumber;
begin
  if Parser.Scan(['0'..'9'], ['0'..'9']) then
    WriteOut(ttNumber);
end;

procedure TEditorConfigLexer.HandleSymbol;
begin
  if Parser.Current in ['[', ']', '=', '*'] then
  begin
    Parser.Next;
    WriteOut(ttSymbol);
  end;
end;

end.
