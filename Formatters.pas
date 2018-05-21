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
  public
    constructor Create(OutputStream: TStream);
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

procedure _WriteOut(OutputStream: TStream; const str: string);
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

procedure _WriteOutLn(OutputStream: TStream; const str: string);
begin
  _WriteOut(OutputStream, str);
  _WriteOut(OutputStream, LineEnding);
end;

constructor TFormatterBase.Create(OutputStream: TStream);
begin
  FOutputStream := OutputStream;
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

  _WriteOut(OutputStream, FormatToken);
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
  _WriteOutLn(OutputStream, '');
  _WriteOutLn(OutputStream, '\par}');
end;

procedure TRTFFormatter.WriteHeader;
begin
  _WriteOutLn(OutputStream, '{\rtf1\ansi\ansicpg1253\deff0\deflang1032');
  _WriteOutLn(OutputStream, '');
  _WriteOutLn(OutputStream, '{\fonttbl');
  _WriteOutLn(OutputStream, '{\f0\fcourier Courier New Greek;}');
  _WriteOutLn(OutputStream, '}');
  _WriteOutLn(OutputStream, '');
  _WriteOutLn(OutputStream, '{\colortbl ;\red0\green0\blue128;}');
  _WriteOutLn(OutputStream, '');
  _WriteOutLn(OutputStream, '\pard\plain \li120 \fs20');
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
    ttPreProcessor:
      FormatToken := '<FONT COLOR=#808080>' + escapedToken + '</FONT>';
    else
      FormatToken := escapedToken;
  end;

  _WriteOut(OutputStream, FormatToken);
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
  _WriteOutLn(OutputStream, '</TT></BODY>');
  _WriteOutLn(OutputStream, '</HTML>');
end;

procedure THTMLFormatter.WriteHeader;
begin
  _WriteOutLn(OutputStream, '<HTML>');
  _WriteOutLn(OutputStream, '<HEAD>');
  _WriteOutLn(OutputStream, '<TITLE></TITLE>');
  _WriteOutLn(OutputStream, '</HEAD>');
  _WriteOutLn(OutputStream, '<BODY><TT>');
end;

end.
