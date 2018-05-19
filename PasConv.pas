unit PasConv;

{$MODE Delphi}

interface

uses SysUtils, Classes;

type
  TPasTokenState = (tsAssembler, tsComment, tsCRLF, tsDirective,
    tsIdentifier, tsKeyWord, tsNumber, tsSpace,
    tsString, tsSymbol, tsUnknown);
  TPasCommentState = (csAnsi, csBor, csNo, csSlashes);

  TFormatterBase = class
    function FormatToken(const NewToken: string; TokenState: TPasTokenState): string;
      virtual; abstract;
    function SetSpecial(const str: string): string; virtual; abstract;
    procedure WriteFooter(OutStream: TStream); virtual; abstract;
    procedure WriteHeader(OutStream: TStream); virtual; abstract;
  end;

  TPasFormatter = class
  private
    FFormatter: TFormatterBase;
    FComment: TPasCommentState;
    FDiffer: boolean;
    FOutStream: TStream;
    FTokenState: TPasTokenState;
    Run, TokenPtr: PChar;
    TokenLen: integer;
    TokenStr: string;
  public
    constructor Create(Formatter: TFormatterBase);
    procedure FormatStream(InStream, OutStream: TStream);
    procedure HandleAnsiC;
    procedure HandleBorC;
    procedure HandleCRLF;
    procedure HandleSlashesC;
    procedure HandleString;
    function IsDiffKey(aToken: string): boolean;
    function IsDirective(aToken: string): boolean;
    function IsKeyWord(aToken: string): boolean;
    procedure WriteOut(const str: string);
    procedure WriteOutLn(const str: string);
  end;

  TPasToRTF = class(TFormatterBase)
    function FormatToken(const NewToken: string; TokenState: TPasTokenState): string;
      override;
    function SetSpecial(const str: string): string; override;
    procedure WriteFooter(OutStream: TStream); override;
    procedure WriteHeader(OutStream: TStream); override;
  end;

  TPasToHTML = class(TFormatterBase)
    function FormatToken(const NewToken: string; TokenState: TPasTokenState): string;
      override;
    function SetSpecial(const str: string): string; override;
    procedure WriteFooter(OutStream: TStream); override;
    procedure WriteHeader(OutStream: TStream); override;
  end;

const
  PasKeywords: array[0..98] of string =
    ('ABSOLUTE', 'ABSTRACT', 'AND', 'ARRAY', 'AS', 'ASM', 'ASSEMBLER',
    'AUTOMATED', 'BEGIN', 'CASE', 'CDECL', 'CLASS', 'CONST', 'CONSTRUCTOR',
    'DEFAULT', 'DESTRUCTOR', 'DISPID', 'DISPINTERFACE', 'DIV', 'DO',
    'DOWNTO', 'DYNAMIC', 'ELSE', 'END', 'EXCEPT', 'EXPORT', 'EXPORTS',
    'EXTERNAL', 'FAR', 'FILE', 'FINALIZATION', 'FINALLY', 'FOR', 'FORWARD',
    'FUNCTION', 'GOTO', 'IF', 'IMPLEMENTATION', 'IN', 'INDEX', 'INHERITED',
    'INITIALIZATION', 'INLINE', 'INTERFACE', 'IS', 'LABEL', 'LIBRARY',
    'MESSAGE', 'MOD', 'NAME', 'NEAR', 'NIL', 'NODEFAULT', 'NOT', 'OBJECT',
    'OF', 'OR', 'OUT', 'OVERRIDE', 'PACKED', 'PASCAL', 'PRIVATE', 'PROCEDURE',
    'PROGRAM', 'PROPERTY', 'PROTECTED', 'PUBLIC', 'PUBLISHED', 'RAISE',
    'READ', 'READONLY', 'RECORD', 'REGISTER', 'REPEAT', 'RESIDENT',
    'RESOURCESTRING', 'SAFECALL', 'SET', 'SHL', 'SHR', 'STDCALL', 'STORED',
    'STRING', 'STRINGRESOURCE', 'THEN', 'THREADVAR', 'TO', 'TRY', 'TYPE',
    'UNIT', 'UNTIL', 'USES', 'VAR', 'VIRTUAL', 'WHILE', 'WITH', 'WRITE',
    'WRITEONLY', 'XOR');

  PasDirectives: array[0..10] of string =
    ('AUTOMATED', 'INDEX', 'NAME', 'NODEFAULT', 'READ', 'READONLY',
    'RESIDENT', 'STORED', 'STRINGRECOURCE', 'WRITE', 'WRITEONLY');

  PasDiffKeys: array[0..6] of string =
    ('END', 'FUNCTION', 'PRIVATE', 'PROCEDURE', 'PRODECTED',
    'PUBLIC', 'PUBLISHED');

procedure PasToHTMLFile(const PasFile, HTMLFile: string);
procedure PasToRTFFile(const PasFile, RTFFile: string);

implementation

procedure PasToHTMLFile(const PasFile, HTMLFile: string);
var
  fmt: TPasToHTML;
  p: TPasFormatter;
  stream1, stream2: TFileStream;
begin
  stream1 := TFileStream.Create(PasFile, fmOpenRead);
  stream2 := TFileStream.Create(HTMLFile, fmCreate);
  fmt := TPasToHTML.Create;
  p := TPasFormatter.Create(fmt);
  p.FormatStream(stream1, stream2);
  fmt.Free;
  stream1.Free;
  stream2.Free;
  p.Free;
end;

procedure PasToRTFFile(const PasFile, RTFFile: string);
var
  fmt: TPasToRTF;
  stream1, stream2: TFileStream;
  p: TPasFormatter;
begin
  stream1 := TFileStream.Create(PasFile, fmOpenRead);
  stream2 := TFileStream.Create(RTFFile, fmCreate);
  fmt := TPasToRTF.Create;
  p := TPasFormatter.Create(fmt);
  p.FormatStream(stream1, stream2);
  fmt.Free;
  stream1.Free;
  stream2.Free;
  p.Free;
end;

constructor TPasFormatter.Create(Formatter: TFormatterBase);
begin
  FFormatter := Formatter;
end;

procedure TPasFormatter.FormatStream(InStream, OutStream: TStream);
var
  FReadBuf: PChar;
  i: integer;
begin
  FOutStream := OutStream;
  FFormatter.WriteHeader(OutStream);
  GetMem(FReadBuf, InStream.Size + 1);
  i := InStream.Read(FReadBuf^, InStream.Size);
  FReadBuf[i] := #0;
  if i > 0 then
  begin
    Run := FReadBuf;
    TokenPtr := Run;
    while Run^ <> #0 do
    begin
      case Run^ of
        #13:
        begin
          FComment := csNo;
          HandleCRLF;
        end;

        #1..#9, #11, #12, #14..#32:
        begin
          while Run^ in [#1..#9, #11, #12, #14..#32] do
            Inc(Run);
          FTokenState := tsSpace;
          TokenLen := Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);
          WriteOut(FFormatter.FormatToken(TokenStr, FTokenState));
          TokenPtr := Run;
        end;

        'A'..'Z', 'a'..'z', '_':
        begin
          FTokenState := tsIdentifier;
          Inc(Run);
          while Run^ in ['A'..'Z', 'a'..'z', '0'..'9', '_'] do
            Inc(Run);
          TokenLen := Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);
          if IsKeyWord(TokenStr) then
          begin
            if IsDirective(TokenStr) then
              FTokenState := tsDirective
            else
              FTokenState := tsKeyWord;
          end;
          WriteOut(FFormatter.FormatToken(TokenStr, FTokenState));
          TokenPtr := Run;
        end;

        '0'..'9':
        begin
          Inc(Run);
          FTokenState := tsNumber;
          while Run^ in ['0'..'9', '.', 'e', 'E'] do
            Inc(Run);
          TokenLen := Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);
          //          SetSpecial;
          WriteOut(TokenStr);
          TokenPtr := Run;
        end;

        '{':
        begin
          FComment := csBor;
          HandleBorC;
        end;

        '!', '"', '%', '&', '('..'/', ':'..'@', '['..'^', '`', '~':
        begin
          FTokenState := tsSymbol;
          while Run^ in ['!', '"', '%', '&', '('..'/', ':'..'@', '['..'^', '`', '~'] do
          begin
            case Run^ of
              '/': if (Run + 1)^ = '/' then
                begin
                  TokenLen := Run - TokenPtr;
                  SetString(TokenStr, TokenPtr, TokenLen);
                  //                     SetSpecial;
                  WriteOut(TokenStr);
                  TokenPtr := Run;
                  FComment := csSlashes;
                  HandleSlashesC;
                  break;
                end;

              '(': if (Run + 1)^ = '*' then
                begin
                  TokenLen := Run - TokenPtr;
                  SetString(TokenStr, TokenPtr, TokenLen);
                  //                     SetSpecial;
                  WriteOut(TokenStr);
                  TokenPtr := Run;
                  FComment := csAnsi;
                  HandleAnsiC;
                  break;
                end;
            end;
            Inc(Run);
          end;
          TokenLen := Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);
          //          SetSpecial;
          WriteOut(TokenStr);
          TokenPtr := Run;
        end;

        #39: HandleString;

        '#':
        begin
          FTokenState := tsString;
          while Run^ in ['#', '0'..'9'] do
            Inc(Run);
          TokenLen := Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);
          //          SetSpecial;
          WriteOut(TokenStr);
          TokenPtr := Run;
        end;

        '$':
        begin
          FTokenState := tsNumber;
          while Run^ in ['$', '0'..'9', 'A'..'F', 'a'..'f'] do
            Inc(Run);
          TokenLen := Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);
          //          SetSpecial;
          WriteOut(TokenStr);
          TokenPtr := Run;
        end;

        else
        begin
          if Run^ <> #0 then
          begin
            Inc(Run);
            TokenLen := Run - TokenPtr;
            SetString(TokenStr, TokenPtr, TokenLen);
            //            SetSpecial;
            WriteOut(TokenStr);
            TokenPtr := Run;
          end
          else
            break;
        end;
      end;
    end;
  end;
  FreeMem(FReadBuf);
  FFormatter.WriteFooter(OutStream);
end;

procedure TPasFormatter.HandleAnsiC;
begin
  while Run^ <> #0 do
  begin
    case Run^ of
      #13:
      begin
        if TokenPtr <> Run then
        begin
          FTokenState := tsComment;
          TokenLen := Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);

          TokenStr := FFormatter.SetSpecial(TokenStr);
          WriteOut(FFormatter.FormatToken(TokenStr, FTokenState));
          TokenPtr := Run;
        end;
        HandleCRLF;
        Dec(Run);
      end;

      '*': if (Run + 1)^ = ')' then
        begin
          Inc(Run, 2);
          break;
        end;
    end;
    Inc(Run);
  end;
  FTokenState := tsComment;
  TokenLen := Run - TokenPtr;
  SetString(TokenStr, TokenPtr, TokenLen);
  TokenStr := FFormatter.SetSpecial(TokenStr);
  WriteOut(FFormatter.FormatToken(TokenStr, FTokenState));
  TokenPtr := Run;
  FComment := csNo;
end;  { HandleAnsiC }

procedure TPasFormatter.HandleBorC;
begin
  while Run^ <> #0 do
  begin
    case Run^ of
      #13:
      begin
        if TokenPtr <> Run then
        begin
          FTokenState := tsComment;
          TokenLen := Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);
          TokenStr := FFormatter.SetSpecial(TokenStr);
          WriteOut(FFormatter.FormatToken(TokenStr, FTokenState));
          TokenPtr := Run;
        end;
        HandleCRLF;
        Dec(Run);
      end;

      '}':
      begin
        Inc(Run);
        break;
      end;

    end;
    Inc(Run);
  end;
  FTokenState := tsComment;
  TokenLen := Run - TokenPtr;
  SetString(TokenStr, TokenPtr, TokenLen);
  TokenStr := FFormatter.SetSpecial(TokenStr);
  WriteOut(FFormatter.FormatToken(TokenStr, FTokenState));
  TokenPtr := Run;
  FComment := csNo;
end;  { HandleBorC }

procedure TPasFormatter.HandleCRLF;
begin
  if Run^ = #0 then
    Exit;
  Inc(Run, 2);
  FTokenState := tsCRLF;
  TokenLen := Run - TokenPtr;
  SetString(TokenStr, TokenPtr, TokenLen);
  WriteOut(FFormatter.FormatToken(TokenStr, FTokenState));
  TokenPtr := Run;
  fComment := csNo;
  FTokenState := tsUnKnown;
  if Run^ = #13 then
    HandleCRLF;
end;  { HandleCRLF }

procedure TPasFormatter.HandleSlashesC;
begin
  FTokenState := tsComment;
  while (Run^ <> #13) and (Run^ <> #0) do
    Inc(Run);
  TokenLen := Run - TokenPtr;
  SetString(TokenStr, TokenPtr, TokenLen);
  TokenStr := FFormatter.SetSpecial(TokenStr);
  WriteOut(FFormatter.FormatToken(TokenStr, FTokenState));
  TokenPtr := Run;
  FComment := csNo;
end;  { HandleSlashesC }

procedure TPasFormatter.HandleString;
begin
  FTokenState := tsSTring;
  FComment := csNo;
  repeat
    case Run^ of
      #0, #10, #13: raise Exception.Create('Invalid string');
    end;
    Inc(Run);
  until Run^ = #39;
  Inc(Run);
  TokenLen := Run - TokenPtr;
  SetString(TokenStr, TokenPtr, TokenLen);
  TokenStr := FFormatter.SetSpecial(TokenStr);
  WriteOut(FFormatter.FormatToken(TokenStr, FTokenState));
  TokenPtr := Run;
end;  { HandleString }

function TPasFormatter.IsDiffKey(aToken: string): boolean;
var
  First, Last, I, Compare: integer;
  Token: string;
begin
  First := Low(PasDiffKeys);
  Last := High(PasDiffKeys);
  Result := False;
  Token := UpperCase(aToken);
  while First <= Last do
  begin
    I := (First + Last) shr 1;
    Compare := CompareStr(PasDiffKeys[i], Token);
    if Compare = 0 then
    begin
      Result := True;
      break;
    end
    else
    if Compare < 0 then
      First := I + 1
    else
      Last := I - 1;
  end;
end;  { IsDiffKey }

function TPasFormatter.IsDirective(aToken: string): boolean;
var
  First, Last, I, Compare: integer;
  Token: string;
begin
  First := Low(PasDirectives);
  Last := High(PasDirectives);
  Result := False;
  Token := UpperCase(aToken);
  if CompareStr('PROPERTY', Token) = 0 then
    FDiffer := True;
  if IsDiffKey(Token) then
    FDiffer := False;
  while First <= Last do
  begin
    I := (First + Last) shr 1;
    Compare := CompareStr(PasDirectives[i], Token);
    if Compare = 0 then
    begin
      Result := True;
      if FDiffer then
      begin
        Result := False;
        if CompareStr('NAME', Token) = 0 then
          Result := True;
        if CompareStr('RESIDENT', Token) = 0 then
          Result := True;
        if CompareStr('STRINGRESOURCE', Token) = 0 then
          Result := True;
      end;
      break;
    end
    else
    if Compare < 0 then
      First := I + 1
    else
      Last := I - 1;
  end;
end;  { IsDirective }

function TPasFormatter.IsKeyWord(aToken: string): boolean;
var
  First, Last, I, Compare: integer;
  Token: string;
begin
  First := Low(PasKeywords);
  Last := High(PasKeywords);
  Result := False;
  Token := UpperCase(aToken);
  while First <= Last do
  begin
    I := (First + Last) shr 1;
    Compare := CompareStr(PasKeywords[i], Token);
    if Compare = 0 then
    begin
      Result := True;
      break;
    end
    else
    if Compare < 0 then
      First := I + 1
    else
      Last := I - 1;
  end;
end;  { IsKeyWord }

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

procedure TPasFormatter.WriteOut(const str: string);
begin
  _WriteOut(FOutStream, str);
end;

procedure TPasFormatter.WriteOutLn(const str: string);
begin
  _WriteOutLn(FOutStream, str);
end;


(* Pascal to RTF converter *)

function TPasToRTF.FormatToken(const NewToken: string;
  TokenState: TPasTokenState): string;
begin
  case TokenState of
    tsCRLF: FormatToken := '\par' + NewToken;
    tsDirective, tsKeyword: FormatToken := '\b ' + NewToken + '\b0 ';
    tsComment: FormatToken := '\cf1\i ' + NewToken + '\cf0\i0 ';
  end;
end;

function TPasToRTF.SetSpecial(const str: string): string;
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

procedure TPasToRTF.WriteFooter(OutStream: TStream);
begin
  _WriteOutLn(OutStream, #13#10'\par}');
end;

procedure TPasToRTF.WriteHeader(OutStream: TStream);
begin
  _WriteOutLn(OutStream, '{\rtf1\ansi\ansicpg1253\deff0\deflang1032'#13#10);
  _WriteOutLn(OutStream, '{\fonttbl');
  _WriteOutLn(OutStream, '{\f0\fcourier Courier New Greek;}');
  _WriteOutLn(OutStream, '}'#13#10);
  _WriteOutLn(OutStream, '{\colortbl ;\red0\green0\blue128;}'#13#10);
  _WriteOutLn(OutStream, '\pard\plain \li120 \fs20');
end;

(* Pascal To HTML Converter *)

function TPasToHTML.FormatToken(const NewToken: string;
  TokenState: TPasTokenState): string;
begin
  case TokenState of
    tsCRLF: FormatToken := '<BR>' + NewToken;
    tsSpace: FormatToken := SetSpecial(NewToken);
    tsDirective, tsKeyWord: FormatToken := '<B>' + NewToken + '</B>';
    tsComment: FormatToken := '<FONT COLOR=#000080><I>' + NewToken + '</I></FONT>';
  end;
end;

function TPasToHTML.SetSpecial(const str: string): string;
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

procedure TPasToHTML.WriteFooter(OutStream: TStream);
begin
  _WriteOutLn(OutStream, '</TT></BODY>');
  _WriteOutLn(OutStream, '</HTML>');
end;

procedure TPasToHTML.WriteHeader(OutStream: TStream);
begin
  _WriteOutLn(OutStream, '<HTML>');
  _WriteOutLn(OutStream, '<HEAD>');
  _WriteOutLn(OutStream, '<TITLE></TITLE>');
  _WriteOutLn(OutStream, '</HEAD>');
  _WriteOutLn(OutStream, '<BODY><TT>');
end;

end.
