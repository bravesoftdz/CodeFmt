unit frmPreferences;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, checklst, Buttons, ComCtrls;

type
  TPreferencesForm = class(TForm)
    PageControl1: TPageControl;
    ShellSheet: TTabSheet;
    btnOk: TBitBtn;
    btnCancel: TBitBtn;
    btnHelp: TBitBtn;
    GroupBox1: TGroupBox;
    ExtentionList: TCheckListBox;
    SelectAll: TButton;
    SelectNone: TButton;
    InvertSelection: TButton;
    procedure FormShow(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure SelectAllClick(Sender: TObject);
    procedure SelectNoneClick(Sender: TObject);
    procedure InvertSelectionClick(Sender: TObject);
  private
    FExtentions: TStringList;
    function GetShellKeyFromExtention(const Extention: string; var Key: HKEY): Boolean;
    function GetFileTypeName(const Extention: string; var TypeName: string): Boolean;
    function IsExtentionSelected(const Extention: string): Boolean;
    procedure Associate(const Extention: string);
    procedure DeAssociate(const Extention: string);
    procedure ReadSelections;
    procedure WriteSelections;
    procedure InitListBox;
  public
    { Public declarations }
  end;

var
  PreferencesForm: TPreferencesForm;

implementation

{$R *.DFM}

const
  MyShellCmd = 'CodeFmt_Open';
  MyShellCmdCaption : string = '’νοιγμα με τη Μορφοποίηση κώδικα';
  MaxExtentions = 7;
  Extentions : array [0..MaxExtentions - 1] of string = (
    '.cpp', '.c', '.h', '.pas', '.p', '.dpr', '.inc');

{ GetShellKeyFromExtention
      Ξέρουμε την επέκταση του αρχείου. Στο μητρώο, κάτω από το κλειδί
    HKEY_CLASSES_ROOT βρίσκεται π.χ. το κλειδί ".cpp". Η προεπιλεγμένη
    τιμή αυτού του κλειδιού είναι το όνομα ενός άλλου κλειδιού το οποίο
    περιέχει μεταξύ άλλων και τις εντολές του κελύφους που είναι συσχε-
    τισμένες με αυτή την επέκταση. Π.χ. η προεπιλεγμένη τιμή του κλει-
    διού ".cpp" είναι "cppfile". Αυτό είναι το κλειδί που επιστρέφει
    αυτή η συνάρτηση. Η χρήση του γίνεται σε άλλες συναρτήσεις.
}

function TPreferencesForm.GetShellKeyFromExtention(const Extention: string; var Key: HKEY): Boolean;
var
  Buf: PChar;
  len: Integer;
begin
  Result := False;
  if RegOpenKeyEx(HKEY_CLASSES_ROOT, PChar(Extention), 0, KEY_ALL_ACCESS, Key) = ERROR_SUCCESS then
  begin
    RegQueryValueEx(Key, nil, nil, nil, nil, @Len);
    GetMem(Buf, Len + 1);
    RegQueryValueEx(Key, nil, nil, nil, PByte(Buf), @Len);
    RegCloseKey(Key);
    Result := RegOpenKeyEx(HKEY_CLASSES_ROOT, Buf, 0, KEY_ALL_ACCESS, Key) = ERROR_SUCCESS;
    FreeMem(Buf);
  end;
end;

function TPreferencesForm.GetFileTypeName(const Extention: string; var TypeName: string): Boolean;
var
  hKey1: HKEY;
  Len : Integer;
begin
  Result := GetShellKeyFromExtention(Extention, hKey1);
  if not Result then Exit;
  Result := RegQueryValueEx(hKey1, nil, nil, nil, nil, @Len) = ERROR_SUCCESS;
  if not Result then Exit;
  SetLength(TypeName, Len - 1);
  Result := RegQueryValueEx(hKey1, nil, nil, nil, PByte(TypeName), @Len) = ERROR_SUCCESS;
end;

function TPreferencesForm.IsExtentionSelected(const Extention: string): Boolean;
var
  hKey1, hKey2: HKEY;
begin
  Result := GetShellKeyFromExtention(Extention, hKey1);
  if not Result then Exit;
  Result := RegOpenKeyEx(hKey1, PChar('shell\' + MyShellCmd), 0, KEY_ALL_ACCESS, hKey2) = ERROR_SUCCESS;
  RegCloseKey(hKey1);
  if Result then RegCloseKey(hkey2);
end;

procedure TPreferencesForm.Associate(const Extention: string);
var
  hKeyRoot, hKey2: HKEY;
  Result: Boolean;
  Disposition : DWORD;
  s: string;
begin
  Result := GetShellKeyFromExtention(Extention, hKeyRoot);
  if not Result then Exit;
  Result := RegCreateKeyEx(hKeyRoot, 'shell', 0,
                           nil, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS,
                           nil, hKey2, @Disposition) = ERROR_SUCCESS;
  RegCloseKey(hKeyRoot);
  if not Result then Exit;
  hKeyRoot := hKey2;

  Result := RegCreateKeyEx(hKeyRoot, MyShellCmd, 0,
                           nil, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS,
                           nil, hKey2, @Disposition) = ERROR_SUCCESS;
  RegCloseKey(hKeyRoot);
  if not Result then Exit;
  hKeyRoot := hKey2;

  RegSetValueEx(hKeyRoot, nil, 0, REG_SZ, PChar(MyShellCmdCaption), Length(MyShellCmdCaption)+1);

  Result := RegCreateKeyEx(hKeyRoot, 'command', 0,
                           nil, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS,
                           nil, hKey2, @Disposition) = ERROR_SUCCESS;
  RegCloseKey(hKeyRoot);
  if not Result then Exit;
  hKeyRoot := hKey2;

  s := '"' + ParamStr(0) + '" "%1"';
  RegSetValueEx(hKeyRoot, nil, 0, REG_SZ, PChar(s), Length(s) + 1);
  RegCloseKey(hKeyRoot);
end;

procedure TPreferencesForm.DeAssociate(const Extention: string);
var
  hKey1: HKEY;
  Result: Boolean;
begin
  Result := GetShellKeyFromExtention(Extention, hKey1);
  if not Result then Exit;
  RegDeleteKey(hKey1, PChar('shell\' + MyShellCmd + '\command'));
  RegDeleteKey(hKey1, PChar('shell\' + MyShellCmd));
  RegCloseKey(hKey1);
end;

procedure TPreferencesForm.InitListBox;
var
  s: string;
  i: Integer;
begin
  FExtentions.Clear;
  ExtentionList.Items.Clear;
  for i:=0 to MaxExtentions - 1 do
    if GetFileTypeName(Extentions[i], s) then begin
      FExtentions.Add(Extentions[i]);
      ExtentionList.Items.Add(s + ' (*' + Extentions[i] + ')');
    end;
end;

procedure TPreferencesForm.ReadSelections;
var
  i : Integer;
begin
  for i := 0 to FExtentions.Count - 1 do
    ExtentionList.Checked[i] := IsExtentionSelected(FExtentions[i]);
end;

procedure TPreferencesForm.WriteSelections;
var
  i : Integer;
begin
  for i := 0 to FExtentions.Count - 1 do
    if ExtentionList.Checked[i] then
      Associate(FExtentions[i])
    else
      DeAssociate(FExtentions[i]);
end;

procedure TPreferencesForm.FormShow(Sender: TObject);
begin
  InitListBox;
  ReadSelections;
end;

procedure TPreferencesForm.btnOkClick(Sender: TObject);
begin
  WriteSelections;
end;

procedure TPreferencesForm.FormCreate(Sender: TObject);
begin
  FExtentions := TStringList.Create;
end;

procedure TPreferencesForm.FormDestroy(Sender: TObject);
begin
  FExtentions.Free;
end;

procedure TPreferencesForm.SelectAllClick(Sender: TObject);
var
  i : Integer;
begin
  for i := 0 to ExtentionList.Items.Count - 1 do
    ExtentionList.Checked[i] := True;
end;

procedure TPreferencesForm.SelectNoneClick(Sender: TObject);
var
  i : Integer;
begin
  for i := 0 to ExtentionList.Items.Count - 1 do
    ExtentionList.Checked[i] := False;
end;

procedure TPreferencesForm.InvertSelectionClick(Sender: TObject);
var
  i : Integer;
begin
  for i := 0 to ExtentionList.Items.Count - 1 do
    ExtentionList.Checked[i] := not ExtentionList.Checked[i];
end;

end.
