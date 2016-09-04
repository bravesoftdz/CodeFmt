unit CppConv;

{$MODE Delphi}

interface

uses SysUtils, Classes;

type
  TCppTokenState = (tsAssembler, tsComment, tsCRLF, tsIdentifier,
    tsKeyWord, tsNumber, tsSpace, tsString, tsSymbol,
    tsPreprocessor, tsUnknown);
  TCppCommentState = (csAnsi, csNo, csSlashes);

  TCppFormatter = class
  private
    FComment: TCppCommentState;
    FOutStream: TStream;
    FTokenState: TCppTokenState;
    Run, TokenPtr: PChar;
    TokenLen: integer;
    TokenStr: string;
  public
    procedure FormatStream(InStream, OutStream: TStream);
    procedure FormatToken(var NewToken: string; TokenState: TCppTokenState); virtual;
    procedure HandleAnsiC;
    procedure HandleCRLF;
    procedure HandleSlashesC;
    procedure HandleString;
    function IsKeyWord(aToken: string): boolean;
    procedure SetSpecial(var str: string); virtual;
    procedure WriteFooter; virtual;
    procedure WriteHeader; virtual;
    procedure WriteOut(const str: string);
    procedure WriteOutLn(const str: string);
  end;

  TCppToRTF = class(TCppFormatter)
    procedure FormatToken(var NewToken: string; TokenState: TCppTokenState); override;
    procedure SetSpecial(var str: string); override;
    procedure WriteFooter; override;
    procedure WriteHeader; override;
  end;

  TCppToHTML = class(TCppFormatter)
    procedure FormatToken(var NewToken: string; TokenState: TCppTokenState); override;
    procedure SetSpecial(var str: string); override;
    procedure WriteFooter; override;
    procedure WriteHeader; override;
  end;

const
  CppKeyWords: array [0..59] of string =
    ('_cs', '_ds', '_es', '_export', '_fastcall',
    '_loadds', '_saveregs', '_seg', '_ss', 'asm',
    'auto', 'break', 'case', 'cdecl', 'char',
    'class', 'const', 'continue', 'default', 'delete',
    'do', 'double', 'else', 'enum', 'extern',
    'far', 'float', 'for', 'friend', 'goto',
    'huge', 'if', 'inline', 'int', 'interrupt',
    'long', 'near', 'new', 'operator', 'pascal',
    'private', 'protected', 'public', 'register', 'return',
    'short', 'signed', 'sizeof', 'static', 'struct',
    'switch', 'template', 'this', 'typedef', 'union',
    'unsigned', 'virtual', 'void', 'volatile', 'while');

procedure CppToHTMLFile(const CppFile, HTMLFile: string);
procedure CppToRTFFile(const CppFile, RTFFile: string);

implementation

procedure CppToHTMLFile(const CppFile, HTMLFile: string);
var
  fmt: TCppToHTML;
  stream1, stream2: TFileStream;
begin
  stream1 := TFileStream.Create(CppFile, fmOpenRead);
  stream2 := TFileStream.Create(HTMLFile, fmCreate);
  fmt := TCppToHTML.Create;
  fmt.FormatStream(stream1, stream2);
  fmt.Free;
  stream1.Free;
  stream2.Free;
end;

procedure CppToRTFFile(const CppFile, RTFFile: string);
var
  fmt: TCppToRTF;
  stream1, stream2: TFileStream;
begin
  stream1 := TFileStream.Create(CppFile, fmOpenRead);
  stream2 := TFileStream.Create(RTFFile, fmCreate);
  fmt := TCppToRTF.Create;
  fmt.FormatStream(stream1, stream2);
  fmt.Free;
  stream1.Free;
  stream2.Free;
end;

procedure TCppFormatter.FormatStream(InStream, OutStream: TStream);
var
  FReadBuf: PChar;
  i: integer;
begin
  FOutStream := OutStream;
  WriteHeader;
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
          FormatToken(TokenStr, FTokenState);
          //          SetSpecial;
          WriteOut(TokenStr);
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
            FTokenState := tsKeyWord;
          FormatToken(TokenStr, FTokenState);
          WriteOut(TokenStr);
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

        '{', '}', '!', '%', '&', '('..'/', ':'..'@', '['..'^', '`', '~':
        begin
          FTokenState := tsSymbol;
          while Run^ in ['{', '}', '!', '%', '&', '('..'/', ':'..'@',
              '['..'^', '`', '~'] do
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
                end

                else if (Run + 1)^ = '*' then
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
          SetSpecial(TokenStr);
          WriteOut(TokenStr);
          TokenPtr := Run;
        end;

        '"': HandleString;
        '#':
        begin
          FTokenState := tsPreprocessor;
          while (Run^ <> #13) do
            Inc(Run);
          TokenLen := Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);
          FormatToken(TokenStr, FTokenState);
          //          SetSpecial;
          WriteOut(TokenStr);
          TokenPtr := Run;
        end;

          (*        '$':
        begin
          FTokenState:= tsNumber;
          while Run^ in ['$','0'..'9', 'A'..'F', 'a'..'f'] do inc(Run);
          TokenLen:= Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);
//          SetSpecial;
          WriteOut(TokenStr);
          TokenPtr:= Run;
        end;*)

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
  WriteFooter;
end;

procedure TCppFormatter.FormatToken(var NewToken: string; TokenState: TCppTokenState);
begin
end;

procedure TCppFormatter.HandleAnsiC;
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

          SetSpecial(TokenStr);
          FormatToken(TokenStr, FTokenState);
          WriteOut(TokenStr);
          TokenPtr := Run;
        end;
        HandleCRLF;
        Dec(Run);
      end;

      '*': if (Run + 1)^ = '/' then
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
  SetSpecial(TokenStr);
  FormatToken(TokenStr, FTokenState);
  WriteOut(TokenStr);
  TokenPtr := Run;
  FComment := csNo;
end;  { HandleAnsiC }

procedure TCppFormatter.HandleCRLF;
begin
  if Run^ = #0 then
    Exit;
  Inc(Run, 2);
  FTokenState := tsCRLF;
  TokenLen := Run - TokenPtr;
  SetString(TokenStr, TokenPtr, TokenLen);
  FormatToken(TokenStr, FTokenState);
  WriteOut(TokenStr);
  TokenPtr := Run;
  fComment := csNo;
  FTokenState := tsUnKnown;
  if Run^ = #13 then
    HandleCRLF;
end;  { HandleCRLF }

procedure TCppFormatter.HandleSlashesC;
begin
  FTokenState := tsComment;
  while (Run^ <> #13) and (Run^ <> #0) do
    Inc(Run);
  TokenLen := Run - TokenPtr;
  SetString(TokenStr, TokenPtr, TokenLen);
  SetSpecial(TokenStr);
  FormatToken(TokenStr, FTokenState);
  WriteOut(TokenStr);
  TokenPtr := Run;
  FComment := csNo;
end;  { HandleSlashesC }

procedure TCppFormatter.HandleString;
begin
  FTokenState := tsString;
  FComment := csNo;
  repeat
    case Run^ of
      #0, #10, #13: raise Exception.Create('Invalid string');
    end;
    Inc(Run);
  until Run^ = '"';
  Inc(Run);
  TokenLen := Run - TokenPtr;
  SetString(TokenStr, TokenPtr, TokenLen);
  SetSpecial(TokenStr);
  FormatToken(TokenStr, FTokenState);
  WriteOut(TokenStr);
  TokenPtr := Run;
end;  { HandleString }


function TCppFormatter.IsKeyWord(aToken: string): boolean;
var
  First, Last, I, Compare: integer;
begin
  First := Low(CppKeywords);
  Last := High(CppKeywords);
  Result := False;
  while First <= Last do
  begin
    I := (First + Last) shr 1;
    Compare := CompareStr(CppKeywords[i], aToken);
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

procedure TCppFormatter.SetSpecial(var str: string);
begin

end;

procedure TCppFormatter.WriteFooter;
begin
end;

procedure TCppFormatter.WriteHeader;
begin
end;

procedure TCppFormatter.WriteOut(const str: string);
var
  b, Buf: PChar;
begin
  if Length(str) > 0 then
  begin
    GetMem(Buf, Length(str) + 1);
    StrCopy(Buf, PChar(str));
    b := Buf;
    FOutStream.Write(Buf^, Length(str));
    FreeMem(b);
  end;
end;

procedure TCppFormatter.WriteOutLn(const str: string);
begin
  WriteOut(str + #13#10);
end;


(* Cpp to RTF converter *)

procedure TCppToRTF.FormatToken(var NewToken: string; TokenState: TCppTokenState);
begin
  case TokenState of
    tsCRLF: NewToken := '\par' + NewToken;
    tsKeyWord: NewToken := '\b ' + NewToken + '\b0 ';
    tsComment: NewToken := '\cf1\i ' + NewToken + '\cf0\i0 ';
    tsPreprocessor: NewToken := '\cf2 ' + NewToken + '\cf0 ';
  end;
end;

procedure TCppToRTF.SetSpecial(var str: string);
var
  i: integer;
  Result: string;
begin
  Result := '';
  for i := 1 to Length(str) do
    case str[i] of
      '\', '{', '}': Result := Result + '\' + str[i];
      else
        Result := Result + str[i];
    end;
  str := Result;
end;

procedure TCppToRTF.WriteFooter;
begin
  WriteOutLn(#13#10'\par}');
end;

procedure TCppToRTF.WriteHeader;
begin
  WriteOutLn('{\rtf1\ansiansicpg1253\deff0\deflang1032'#13#10);
  WriteOutLn('{\fonttbl');
  WriteOutLn('{\f0\fcourier Courier New Greek;}');
  WriteOutLn('}'#13#10);
  WriteOutLn('{\colortbl ;\red0\green0\blue128;\red0\green128\blue128;}'#13#10);
  WriteOutLn('\pard\plain \li120 \fs20');
end;

(* Cpp To HTML Converter *)

procedure TCppToHTML.FormatToken(var NewToken: string; TokenState: TCppTokenState);
begin
  case TokenState of
    tsCRLF: NewToken := '<BR>' + NewToken;
    tsSpace: SetSpecial(NewToken);
    tsKeyWord: NewToken := '<B>' + NewToken + '</B>';
    tsComment: NewToken := '<FONT COLOR=#000080><I>' + NewToken + '</I></FONT>';
  end;
end;

procedure TCppToHTML.SetSpecial(var str: string);
var
  i: integer;
  Result: string;
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
  str := Result;
end;

procedure TCppToHTML.WriteFooter;
begin
  WriteOutLn('</TT></BODY>');
  WriteOutLn('</HTML>');
end;

procedure TCppToHTML.WriteHeader;
begin
  WriteOutLn('<HTML>');
  WriteOutLn('<HEAD>');
  WriteOutLn('<TITLE></TITLE>');
  WriteOutLn('</HEAD>');
  WriteOutLn('<BODY><TT>');
end;

end.
