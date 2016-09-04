unit PasConv;

interface

uses SysUtils, Classes;

type
  TPasTokenState   = (tsAssembler, tsComment, tsCRLF, tsDirective,
                      tsIdentifier, tsKeyWord, tsNumber, tsSpace,
                      tsString, tsSymbol, tsUnknown);
  TPasCommentState = (csAnsi, csBor, csNo, csSlashes);

  TPasFormatter = class
  private
    FComment: TPasCommentState;
    FDiffer: Boolean;
    FOutStream: TStream;
    FTokenState: TPasTokenState;
    Run, TokenPtr: PChar;
    TokenLen: Integer;
    TokenStr: string;
  public
    procedure FormatStream(InStream, OutStream: TStream);
    procedure FormatToken(var NewToken: string; TokenState: TPasTokenState); virtual;
    procedure HandleAnsiC;
    procedure HandleBorC;
    procedure HandleCRLF;
    procedure HandleSlashesC;
    procedure HandleString;
    function IsDiffKey(aToken: String): Boolean;
    function IsDirective(aToken: String): Boolean;
    function IsKeyWord(aToken: String): Boolean;
    function SetSpecial(const str: string): string; virtual;
    procedure WriteFooter; virtual;
    procedure WriteHeader; virtual;
    procedure WriteOut(const str: string);
    procedure WriteOutLn(const str: string);
  end;

  TPasToRTF = class(TPasFormatter)
    procedure FormatToken(var NewToken: string; TokenState: TPasTokenState); override;
    function SetSpecial(const str: string): string; override;
    procedure WriteFooter; override;
    procedure WriteHeader; override;
  end;

  TPasToHTML = class(TPasFormatter)
    procedure FormatToken(var NewToken: string; TokenState: TPasTokenState); override;
    function SetSpecial(const str: string): string; override;
    procedure WriteFooter; override;
    procedure WriteHeader; override;
  end;

const
  PasKeywords : array[0..98] of string =
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

  PasDirectives : array[0..10] of string =
              ('AUTOMATED', 'INDEX', 'NAME', 'NODEFAULT', 'READ', 'READONLY',
               'RESIDENT', 'STORED', 'STRINGRECOURCE', 'WRITE', 'WRITEONLY');

  PasDiffKeys: array[0..6] of string =
           ('END', 'FUNCTION', 'PRIVATE', 'PROCEDURE', 'PRODECTED', 'PUBLIC', 'PUBLISHED');

procedure PasToHTMLFile(const PasFile, HTMLFile: string);
procedure PasToRTFFile(const PasFile, RTFFile: string);

implementation

procedure PasToHTMLFile(const PasFile, HTMLFile: string);
var
  fmt: TPasToHTML;
  stream1, stream2: TFileStream;
begin
  stream1 := TFileStream.Create(PasFile, fmOpenRead);
  stream2 := TFileStream.Create(HTMLFile, fmCreate);
  fmt := TPasToHTML.Create;
  fmt.FormatStream(stream1, stream2);
  fmt.Free;
  stream1.Free;
  stream2.Free;
end;

procedure PasToRTFFile(const PasFile, RTFFile: string);
var
  fmt: TPasToRTF;
  stream1, stream2: TFileStream;
begin
  stream1 := TFileStream.Create(PasFile, fmOpenRead);
  stream2 := TFileStream.Create(RTFFile, fmCreate);
  fmt := TPasToRTF.Create;
  fmt.FormatStream(stream1, stream2);
  fmt.Free;
  stream1.Free;
  stream2.Free;
end;

procedure TPasFormatter.FormatStream(InStream, OutStream: TStream);
var
  FReadBuf : PChar;
  i: Integer;
begin
  FOutStream := OutStream;
  WriteHeader;
  GetMem(FReadBuf, InStream.Size + 1);
  i := InStream.Read(FReadBuf^, InStream.Size);
  FReadBuf[i] := #0;
  if i > 0 then begin
    Run := FReadBuf;
    TokenPtr := Run;
    while Run^ <> #0 do begin
      Case Run^ of
        #13:
        begin
          FComment:= csNo;
          HandleCRLF;
        end;

        #1..#9, #11, #12, #14..#32:
        begin
          while Run^ in [#1..#9, #11, #12, #14..#32] do inc(Run);
          FTokenState:= tsSpace;
          TokenLen:= Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);
          FormatToken(TokenStr, FTokenState);
//          SetSpecial;
          WriteOut(TokenStr);
          TokenPtr:= Run;
        end;

        'A'..'Z', 'a'..'z', '_':
        begin
          FTokenState:= tsIdentifier;
          inc(Run);
          while Run^ in ['A'..'Z', 'a'..'z', '0'..'9', '_'] do inc(Run);
          TokenLen:= Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);
          if IsKeyWord(TokenStr) then
          begin
            if IsDirective(TokenStr) then FTokenState:= tsDirective
              else FTokenState:= tsKeyWord;
          end;
          FormatToken(TokenStr, FTokenState);
          WriteOut(TokenStr);
          TokenPtr:= Run;
        end;

        '0'..'9':
        begin
          inc(Run);
          FTokenState:= tsNumber;
          while Run^ in ['0'..'9', '.', 'e', 'E'] do inc(Run);
          TokenLen:= Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);
//          SetSpecial;
          WriteOut(TokenStr);
          TokenPtr:= Run;
        end;

        '{':
        begin
          FComment:= csBor;
          HandleBorC;
        end;

        '!','"', '%', '&', '('..'/', ':'..'@', '['..'^', '`', '~' :
        begin
          FTokenState:= tsSymbol;
          while Run^ in ['!','"', '%', '&', '('..'/', ':'..'@', '['..'^', '`', '~'] do
          begin
            Case Run^ of
              '/': if (Run + 1)^ = '/' then
                   begin
                     TokenLen:= Run - TokenPtr;
                     SetString(TokenStr, TokenPtr, TokenLen);
//                     SetSpecial;
                     WriteOut(TokenStr);
                     TokenPtr:= Run;
                     FComment:= csSlashes;
                     HandleSlashesC;
                     break;
                   end;

              '(': if (Run + 1)^ = '*' then
                   begin
                     TokenLen:= Run - TokenPtr;
                     SetString(TokenStr, TokenPtr, TokenLen);
//                     SetSpecial;
                     WriteOut(TokenStr);
                     TokenPtr:= Run;
                     FComment:= csAnsi;
                     HandleAnsiC;
                     break;
                   end;
            end;
            inc(Run);
          end;
          TokenLen:= Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);
//          SetSpecial;
          WriteOut(TokenStr);
          TokenPtr:= Run;
        end;

        #39: HandleString;

        '#':
        begin
          FTokenState:= tsString;
          while Run^ in ['#', '0'..'9'] do inc(Run);
          TokenLen:= Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);
//          SetSpecial;
          WriteOut(TokenStr);
          TokenPtr:= Run;
        end;

        '$':
        begin
          FTokenState:= tsNumber;
          while Run^ in ['$','0'..'9', 'A'..'F', 'a'..'f'] do inc(Run);
          TokenLen:= Run - TokenPtr;
          SetString(TokenStr, TokenPtr, TokenLen);
//          SetSpecial;
          WriteOut(TokenStr);
          TokenPtr:= Run;
        end;

        else
        begin
          if Run^ <> #0 then begin
            inc(Run);
            TokenLen:= Run - TokenPtr;
            SetString(TokenStr, TokenPtr, TokenLen);
//            SetSpecial;
            WriteOut(TokenStr);
            TokenPtr:= Run;
          end else break;
        end;
      end;
    end;
  end;
  FreeMem(FReadBuf);
  WriteFooter;
end;

procedure TPasFormatter.FormatToken(var NewToken: string; TokenState: TPasTokenState);
begin
end;

procedure TPasFormatter.HandleAnsiC;
begin
  while Run^ <> #0 do
  begin
    Case Run^ of
      #13:
        begin
          if TokenPtr <> Run then
          begin
            FTokenState:= tsComment;
            TokenLen:= Run - TokenPtr;
            SetString(TokenStr, TokenPtr, TokenLen);

            TokenStr := SetSpecial(TokenStr);
            FormatToken(TokenStr, FTokenState);
            WriteOut(TokenStr);
            TokenPtr:= Run;
          end;
          HandleCRLF;
          dec(Run);
        end;

      '*': if (Run +1 )^ = ')' then begin  inc(Run, 2); break; end;
    end;
    inc(Run);
  end;
  FTokenState:= tsComment;
  TokenLen:= Run - TokenPtr;
  SetString(TokenStr, TokenPtr, TokenLen);
  TokenStr := SetSpecial(TokenStr);
  FormatToken(TokenStr, FTokenState);
  WriteOut(TokenStr);
  TokenPtr:= Run;
  FComment:= csNo;
end;  { HandleAnsiC }

procedure TPasFormatter.HandleBorC;
begin
  while Run^ <> #0 do begin
    Case Run^ of
      #13:
        begin
          if TokenPtr <> Run then
          begin
            FTokenState:= tsComment;
            TokenLen:= Run - TokenPtr;
            SetString(TokenStr, TokenPtr, TokenLen);
            TokenStr := SetSpecial(TokenStr);
            FormatToken(TokenStr, FTokenState);
            WriteOut(TokenStr);
            TokenPtr:= Run;
          end;
          HandleCRLF;
          dec(Run);
        end;

      '}': begin  inc(Run); break; end;

    end;
    inc(Run);
  end;
  FTokenState:= tsComment;
  TokenLen:= Run - TokenPtr;
  SetString(TokenStr, TokenPtr, TokenLen);
  TokenStr := SetSpecial(TokenStr);
  FormatToken(TokenStr, FTokenState);
  WriteOut(TokenStr);
  TokenPtr:= Run;
  FComment:= csNo;
end;  { HandleBorC }

procedure TPasFormatter.HandleCRLF;
begin
  if Run^ = #0 then Exit;
  Inc(Run, 2);
  FTokenState:= tsCRLF;
  TokenLen:= Run - TokenPtr;
  SetString(TokenStr, TokenPtr, TokenLen);
  FormatToken(TokenStr, FTokenState);
  WriteOut(TokenStr);
  TokenPtr:= Run;
  fComment:= csNo;
  FTokenState:= tsUnKnown;
  if Run^ = #13 then HandleCRLF;
end;  { HandleCRLF }

procedure TPasFormatter.HandleSlashesC;
begin
  FTokenState:= tsComment;
  while (Run^ <> #13) and (Run^ <> #0) do inc(Run);
  TokenLen:= Run - TokenPtr;
  SetString(TokenStr, TokenPtr, TokenLen);
  TokenStr := SetSpecial(TokenStr);
  FormatToken(TokenStr, FTokenState);
  WriteOut(TokenStr);
  TokenPtr:= Run;
  FComment:= csNo;
end;  { HandleSlashesC }

procedure TPasFormatter.HandleString;
begin
  FTokenState:= tsSTring;
  FComment:= csNo;
  repeat
    Case Run^ of
      #0, #10, #13: raise exception.Create('Invalid string');
    end;
    inc(Run);
  until Run^ = #39;
  inc(Run);
  TokenLen:= Run - TokenPtr;
  SetString(TokenStr, TokenPtr, TokenLen);
  TokenStr := SetSpecial(TokenStr);
  FormatToken(TokenStr, FTokenState);
  WriteOut(TokenStr);
  TokenPtr:= Run;
end;  { HandleString }

function TPasFormatter.IsDiffKey(aToken: String):Boolean;
var
  First, Last, I, Compare: Integer;
  Token: String;
begin
  First := Low(PasDiffKeys);
  Last := High(PasDiffKeys);
  Result := False;
  Token:= UpperCase(aToken);
  while First <= Last do
  begin
    I := (First + Last) shr 1;
    Compare := CompareStr(PasDiffKeys[i],Token);
    if Compare = 0 then
      begin
        Result:=True;
        break;
      end
    else
    if Compare < 0  then First := I + 1 else Last := I - 1;
  end;
end;  { IsDiffKey }

function TPasFormatter.IsDirective(aToken: String):Boolean;
var
  First, Last, I, Compare: Integer;
  Token: String;
begin
  First := Low(PasDirectives);
  Last := High(PasDirectives);
  Result := False;
  Token:= UpperCase(aToken);
  if CompareStr('PROPERTY', Token) = 0 then FDiffer:= True;
  if IsDiffKey(Token) then FDiffer:= False;
  while First <= Last do
  begin
    I := (First + Last) shr 1;
    Compare := CompareStr(PasDirectives[i],Token);
    if Compare = 0 then
      begin
        Result:= True;
        if FDiffer then
        begin
          Result:= False;
          if CompareStr('NAME', Token) = 0 then Result:= True;
          if CompareStr('RESIDENT', Token) = 0 then Result:= True;
          if CompareStr('STRINGRESOURCE', Token) = 0 then Result:= True;
        end;
        break;
      end
    else
    if Compare < 0  then First := I + 1 else Last := I - 1;
  end;
end;  { IsDirective }

function TPasFormatter.IsKeyWord(aToken: String):Boolean;
var
  First, Last, I, Compare: Integer;
  Token: String;
begin
  First := Low(PasKeywords);
  Last := High(PasKeywords);
  Result := False;
  Token:= UpperCase(aToken);
  while First <= Last do
  begin
    I := (First + Last) shr 1;
    Compare := CompareStr(PasKeywords[i],Token);
    if Compare = 0 then
      begin
        Result:=True;
        break;
      end
    else
    if Compare < 0  then First := I + 1 else Last := I - 1;
  end;
end;  { IsKeyWord }

function TPasFormatter.SetSpecial(const str: string): string;
begin

end;

procedure TPasFormatter.WriteFooter;
begin
end;

procedure TPasFormatter.WriteHeader;
begin
end;

procedure TPasFormatter.WriteOut(const str: string);
var
  b, Buf: PChar;
begin
  if Length(str) > 0 then begin
    GetMem(Buf, Length(str)+1);
    StrCopy(Buf, PChar(str));
    b := Buf;
    FOutStream.Write(Buf^, Length(str));
    FreeMem(b);
  end;
end;

procedure TPasFormatter.WriteOutLn(const str: string);
begin
  WriteOut(str + #13#10);
end;


(* Pascal to RTF converter *)

procedure TPasToRTF.FormatToken(var NewToken: string; TokenState: TPasTokenState);
begin
  case TokenState of
    tsCRLF: NewToken := '\par' + NewToken;
    tsDirective, tsKeyWord: NewToken := '\b ' + NewToken + '\b0 ';
    tsComment: NewToken := '\cf1\i ' + NewToken + '\cf0\i0 ';
  end;
end;

function TPasToRTF.SetSpecial(const str: string): string;
var
  i: Integer;
begin
  Result := '';
  for i:=1 to Length(str) do
    case str[i] of
      '\', '{', '}': Result := Result + '\' + str[i];
      else Result := Result + str[i];
    end;
end;

procedure TPasToRTF.WriteFooter;
begin
  WriteOutLn(#13#10'\par}');
end;

procedure TPasToRTF.WriteHeader;
begin
  WriteOutLn('{\rtf1\ansi\ansicpg1253\deff0\deflang1032'#13#10);
  WriteOutLn('{\fonttbl');
  WriteOutLn('{\f0\fcourier Courier New Greek;}');
  WriteOutLn('}'#13#10);
  WriteOutLn('{\colortbl ;\red0\green0\blue128;}'#13#10);
  WriteOutLn('\pard\plain \li120 \fs20');
end;

(* Pascal To HTML Converter *)

procedure TPasToHTML.FormatToken(var NewToken: string; TokenState: TPasTokenState);
begin
  case TokenState of
    tsCRLF: NewToken := '<BR>' + NewToken;
    tsSpace: NewToken := SetSpecial(NewToken);
    tsDirective, tsKeyWord: NewToken := '<B>' + NewToken + '</B>';
    tsComment: NewToken := '<FONT COLOR=#000080><I>'+NewToken+'</I></FONT>';
  end;
end;

function TPasToHTML.SetSpecial(const str: string): string;
var
  i: Integer;
begin
  Result := '';
  for i:=1 to Length(str) do
    case str[i] of
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '&': Result := Result + '&amp;';
      '"': Result := Result + '&quot;';
      ' ':
           if (i < Length(str)) and (str[i+1] = ' ') then
             Result := Result + '&nbsp;'
           else
             Result := Result + ' ';
      else Result := Result + str[i];
    end;
end;

procedure TPasToHTML.WriteFooter;
begin
  WriteOutLn('</TT></BODY>');
  WriteOutLn('</HTML>');
end;

procedure TPasToHTML.WriteHeader;
begin
  WriteOutLn('<HTML>');
  WriteOutLn('<HEAD>');
  WriteOutLn('<TITLE></TITLE>');
  WriteOutLn('</HEAD>');
  WriteOutLn('<BODY><TT>');
end;

end.
