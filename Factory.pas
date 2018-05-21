unit Factory;

{$mode delphi}

interface

uses
  Classes, SysUtils;

type
  TDocumentType = (dtNone, dtCpp, dtPascal, dtEditorConfig);

  TFormatterType = (ftHtml, ftRtf);

procedure Process(FormatterType: TFormatterType; DocumentType: TDocumentType; InputStream, OutputStream: TStream);

implementation

uses
  LexerBase, PascalLexer, CppLexer, EditorConfigLexer,
  FormatterBase, RTFFormatter, HTMLFormatter;

function CreateFormatter(FormatterType: TFormatterType; OutputStream: TStream): TFormatterBase;
begin
  case FormatterType of
    ftHtml:
      Result := THTMLFormatter.Create(OutputStream);
    ftRtf:
      Result := TRTFFormatter.Create(OutputStream);
    else
      raise Exception.Create('Not implemented!');
  end;
end;

function CreateLexer(DocumentType: TDocumentType; Formatter: TFormatterBase): TLexerBase;
begin
  case DocumentType of
    dtCpp:
      Result := TCppLexer.Create(Formatter.WriteToken);
    dtPascal:
      Result := TPascalLexer.Create(Formatter.WriteToken);
    dtEditorConfig:
      Result := TEditorConfigLexer.Create(Formatter.WriteToken);
    else
      raise Exception.Create('Not implemented');
  end;
end;

procedure Process(FormatterType: TFormatterType; DocumentType: TDocumentType; InputStream, OutputStream: TStream);
var
  formatter: TFormatterBase;
  lexer: TLexerBase;
begin
  formatter := CreateFormatter(FormatterType, OutputStream);
  try
    formatter.WriteHeader;
    lexer := CreateLexer(DocumentType, formatter);
    try
      lexer.FormatStream(InputStream);
    finally
      lexer.Free;
    end;
    formatter.WriteFooter;
  finally
    formatter.Free;
  end;
end;

end.

