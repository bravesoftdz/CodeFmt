program CodeFmt;

{$MODE Delphi}

uses
  SysUtils,
  Forms,
  Interfaces,
  frmMain in 'frmMain.pas' {MainForm},
  PasConv in 'PasConv.pas',
  CppConv in 'CppConv.pas',
  frmAbout in 'frmAbout.pas' {AboutForm};

{$R *.res}

  function RightSeekPos(const substr, s: string): integer;
  var
    i, k: integer;
  begin
    k := Length(substr);
    i := Length(s) - k + 1;
    while (i > 0) and (Copy(s, i, k) <> substr) do
      i := i - 1;
    Result := i;
  end;

const  //False is HTML and True is RTF
  sExt: array [False..True] of string = ('.html', '.rtf');
var
  sFileName: string;
  sName: string;
  sFormatted: string;
  RTFOrHTML: boolean;
  i: integer;
begin
  if (ParamCount = 2) or (ParamCount = 3) then
  begin
    if (UpperCase(ParamStr(1)) <> 'RTF') and (UpperCase(ParamStr(1)) <> 'HTML') then
      Exit;
    RTFOrHTML := UpperCase(ParamStr(1)) = 'RTF';

    sFileName := ParamStr(2);
    i := RightSeekPos('.', sFileName);
    if (i = 0) and (not FileExists(sFileName)) then
    begin
      sName := sFileName;
      sFileName := sFileName + '.pas';
    end
    else
      sName := Copy(sFileName, 1, i - 1);

    sFormatted := ParamStr(3);
    if sFormatted = '' then
      sFormatted := sName + sExt[RTFOrHTML]
    else if RightSeekPos('.', sFormatted) = 0 then
      sFormatted := sFormatted + sExt[RTFOrHTML];
    if RTFOrHTML then
      PasToRTFFile(sFileName, sFormatted)
    else
      PasToHTMLFile(sFileName, sFormatted);
  end
  else
  begin
    Application.Initialize;
    Application.Title := 'Μορφοποίηση κώδικα';
    Application.CreateForm(TMainForm, MainForm);
    Application.CreateForm(TAboutForm, AboutForm);
    if (ParamCount = 1) and FileExists(ParamStr(1)) then
      MainForm.OpenFile(ParamStr(1));
    Application.Run;
  end;
end.
