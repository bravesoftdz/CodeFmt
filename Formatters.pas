unit Formatters;

{$mode delphi}

interface

uses
  Classes, SysUtils;

type
  TTokenType = (ttAssembler, ttComment, ttCRLF, ttDirective,
    ttIdentifier, ttKeyWord, ttNumber, ttSpace,
    ttString, ttSymbol, ttUnknown);

  TFormatterBase = class
  private
    FOutStream: TStream;
  protected
    property OutStream: TStream read FOutStream;
  public
    constructor Create(OutStream: TStream);
    procedure WriteHeader; virtual; abstract;
    procedure WriteFooter; virtual; abstract;
    procedure WriteToken(const NewToken: string; TokenState: TTokenType); virtual; abstract;
  end;

  TRTFFormatter = class(TFormatterBase)
  private
    function SetSpecial(const str: string): string;
  public
    procedure WriteFooter; override;
    procedure WriteHeader; override;
    procedure WriteToken(const NewToken: string; TokenState: TTokenType); override;
  end;

  THTMLFormatter = class(TFormatterBase)
  private
    function SetSpecial(const str: string): string;
  public
    procedure WriteFooter; override;
    procedure WriteHeader; override;
    procedure WriteToken(const NewToken: string; TokenState: TTokenType); override;
  end;

implementation

procedure _WriteOut(OutStream: TStream; const str: string);
var
  b, Buf: PChar;
begin
  if Length(str) > 0 then
  begin
    GetMem(Buf, Length(str) + 1);
    StrCopy(Buf, PChar(str));
    b := Buf;
    OutStream.Write(Buf^, Length(str));
    FreeMem(b);
  end;
end;

procedure _WriteOutLn(OutStream: TStream; const str: string);
begin
  _WriteOut(OutStream, str);
  _WriteOut(OutStream, LineEnding);
end;

constructor TFormatterBase.Create(OutStream: TStream);
begin
  FOutStream := OutStream;
end;

(* Pascal to RTF converter *)

procedure TRTFFormatter.WriteToken(const NewToken: string;
  TokenState: TTokenType);
var
  escapedToken, FormatToken: string;
begin
  escapedToken := SetSpecial(NewToken);
  case TokenState of
    ttCRLF:
      FormatToken := '\par' + escapedToken;
    ttDirective, ttKeyword:
      FormatToken := '\b ' + escapedToken + '\b0 ';
    ttComment:
      FormatToken := '\cf1\i ' + escapedToken + '\cf0\i0 ';
    else
      FormatToken := escapedToken;
  end;

  _WriteOut(OutStream, FormatToken);
end;

function TRTFFormatter.SetSpecial(const str: string): string;
var
  i: integer;
begin
  Result := '';
  for i := 1 to Length(str) do
    case str[i] of
      '\', '{', '}': Result := Result + '\' + str[i];
      else
        Result := Result + str[i];
    end;
end;

procedure TRTFFormatter.WriteFooter;
begin
  _WriteOutLn(OutStream, '');
  _WriteOutLn(OutStream, '\par}');
end;

procedure TRTFFormatter.WriteHeader;
begin
  _WriteOutLn(OutStream, '{\rtf1\ansi\ansicpg1253\deff0\deflang1032');
  _WriteOutLn(OutStream, '');
  _WriteOutLn(OutStream, '{\fonttbl');
  _WriteOutLn(OutStream, '{\f0\fcourier Courier New Greek;}');
  _WriteOutLn(OutStream, '}');
  _WriteOutLn(OutStream, '');
  _WriteOutLn(OutStream, '{\colortbl ;\red0\green0\blue128;}');
  _WriteOutLn(OutStream, '');
  _WriteOutLn(OutStream, '\pard\plain \li120 \fs20');
end;

(* Pascal To HTML Converter *)

procedure THTMLFormatter.WriteToken(const NewToken: string;
  TokenState: TTokenType);
var
  escapedToken, FormatToken: string;
begin
  escapedToken := SetSpecial(NewToken);
  case TokenState of
    ttCRLF:
      FormatToken := '<BR>' + escapedToken;
    ttDirective, ttKeyWord:
      FormatToken := '<B>' + escapedToken + '</B>';
    ttComment:
      FormatToken := '<FONT COLOR=#000080><I>' + escapedToken + '</I></FONT>';
    ttUnknown:
      FormatToken := '<FONT COLOR=#FF0000><B>' + escapedToken + '</B></FONT>';
    else
      FormatToken := escapedToken;
  end;

  _WriteOut(OutStream, FormatToken);
end;

function THTMLFormatter.SetSpecial(const str: string): string;
var
  i: integer;
begin
  Result := '';
  for i := 1 to Length(str) do
    case str[i] of
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '&': Result := Result + '&amp;';
      '"': Result := Result + '&quot;';
      ' ':
        if (i < Length(str)) and (str[i + 1] = ' ') then
          Result := Result + '&nbsp;'
        else
          Result := Result + ' ';
      else
        Result := Result + str[i];
    end;
end;

procedure THTMLFormatter.WriteFooter;
begin
  _WriteOutLn(OutStream, '</TT></BODY>');
  _WriteOutLn(OutStream, '</HTML>');
end;

procedure THTMLFormatter.WriteHeader;
begin
  _WriteOutLn(OutStream, '<HTML>');
  _WriteOutLn(OutStream, '<HEAD>');
  _WriteOutLn(OutStream, '<TITLE></TITLE>');
  _WriteOutLn(OutStream, '</HEAD>');
  _WriteOutLn(OutStream, '<BODY><TT>');
end;

end.
