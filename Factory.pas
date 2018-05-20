unit Factory;

{$mode delphi}

interface

uses
  Classes, SysUtils;

type
  TDocumentType = (dtNone, dtCpp, dtPascal, dtEditorConfig);

  TFormatterType = (ftHtml, ftRtf);

procedure Process(FormatterType: TFormatterType; DocumentType: TDocumentType; inputStream, outputStream: TStream);

implementation

uses PasConv, CppConv, Formatters, EditorConfigLexer, LexerBase;

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

function CreateLexer(DocumentType: TDocumentType; Formatter: TFormatterBase): TLexBase;
begin
  case DocumentType of
    dtCpp:
      Result := TCppFormatter.Create(Formatter);
    dtPascal:
      Result := TPasFormatter.Create(Formatter);
    dtEditorConfig:
      Result := TEditorConfigLexer.Create(Formatter);
    else
      raise Exception.Create('Not implemented');
  end;
end;

procedure Process(FormatterType: TFormatterType; DocumentType: TDocumentType; inputStream, outputStream: TStream);
var
  formatter: TFormatterBase;
  lexer: TLexBase;
begin
  formatter := CreateFormatter(FormatterType, outputStream);
  try
    lexer := CreateLexer(DocumentType, formatter);
    try
      lexer.FormatStream(inputStream);
    finally
      lexer.Free;
    end;
  finally
    formatter.Free;
  end;
end;

end.

