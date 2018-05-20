unit frmMain;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, SysUtils, Classes, Graphics, Controls,
  Forms, Dialogs, ComCtrls, Buttons, ExtCtrls, Menus,
  IpHtml;

type
  TDocumentType = (dtNone, dtCpp, dtPascal);

  TStreamPipe = procedure(inputStream, outputStream: TStream);

  { TMainForm }

  TMainForm = class(TForm)
    IpHtmlPanel1: TIpHtmlPanel;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    MainMenu1: TMainMenu;
    FileMenu: TMenuItem;
    FileOpen: TMenuItem;
    FileExit: TMenuItem;
    FileSaveAs: TMenuItem;
    ToolsMenu: TMenuItem;
    ToolsPref: TMenuItem;
    HelpMenu: TMenuItem;
    HelpAbout: TMenuItem;
    ImageList1: TImageList;
    ToolBar1: TToolBar;
    btnFileOpen: TToolButton;
    btnFileSave: TToolButton;
    StatusBar1: TStatusBar;
    procedure FileOpenClick(Sender: TObject);
    procedure FileExitClick(Sender: TObject);
    procedure ToolsPrefClick(Sender: TObject);
    procedure HelpAboutClick(Sender: TObject);
    procedure FileSaveAsClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure SaveDialog1TypeChange(Sender: TObject);
  private
    FDocType: TDocumentType;
    FCurFileName: string;
    procedure SetDocType(Value: TDocumentType);
    procedure SetCurFileName(const Value: string);
    procedure OpenFile(const FileName: string; aDocType: TDocumentType; processor: TStreamPipe); overload;
    property DocType: TDocumentType read FDocType write SetDocType;
    property CurFileName: string read FCurFileName write SetCurFileName;
  public
    procedure OpenCppFile(const FileName: string);
    procedure OpenPasFile(const FileName: string);
    procedure OpenFile(const FileName: string); overload;
  end;

var
  MainForm: TMainForm;

implementation

uses PasConv, CppConv, frmAbout;

{$R *.lfm}


procedure TMainForm.SetCurFileName(const Value: string);
begin
  FCurFileName := Value;
  Statusbar1.SimpleText := Value;
end;

procedure TMainForm.SetDocType(Value: TDocumentType);
begin
  FDocType := Value;
  btnFileSave.Enabled := FDocType <> dtNone;
  FileSaveAs.Enabled := FDocType <> dtNone;
end;

procedure TMainForm.OpenFile(const FileName: string; aDocType: TDocumentType; processor: TStreamPipe);
var
  inputStream: TFileStream;
  outputStream: TMemoryStream;
begin
  inputStream := TFileStream.Create(FileName, fmOpenRead);
  try
    outputStream := TMemoryStream.Create;
    try
      processor(inputStream, outputStream);
      outputStream.seek(0, 0);
      IpHtmlPanel1.SetHtmlFromStream(outputStream);
      DocType := aDocType;
      CurFileName := FileName;
    finally
      outputStream.Free;
    end;
  finally
    inputStream.Free;
  end;
end;

procedure TMainForm.OpenCppFile(const FileName: string);
begin
  OpenFile(FileName, dtCpp, CppToHTMLStream);
end;

procedure TMainForm.OpenPasFile(const FileName: string);
begin
  OpenFile(Filename, dtPascal, PasToHTMLStream);
end;

procedure TMainForm.FileOpenClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
    OpenFile(OpenDialog1.FileName);
end;

procedure TMainForm.FileExitClick(Sender: TObject);
begin
  Close;
end;

{
  Opens the preferences dialog (TODO)
}
procedure TMainForm.ToolsPrefClick(Sender: TObject);
begin
end;

procedure TMainForm.HelpAboutClick(Sender: TObject);
begin
  AboutForm.ShowModal;
end;

function IsCppFileExtension(const extension: string): boolean;
begin
  IsCppFileExtension := (extension = '.cpp') or (extension = '.c') or (extension = '.h');
end;

function IsPascalFileExtension(const extension: string): boolean;
begin
  IsPascalFileExtension := (extension = '.pas') or (extension = '.dpr') or
    (extension = '.lpr');
end;

procedure TMainForm.OpenFile(const FileName: string);
var
  s: string;
begin
  s := ExtractFileExt(FileName);
  if IsCppFileExtension(s) then
    OpenCppFile(FileName)
  else if IsPascalFileExtension(s) then
    OpenPasFile(FileName)
  else
    MessageDlg('Αυτή η μορφή δεν υποστηρίζεται (' + s + ').', mtError, [mbOK], 0);
end;

procedure TMainForm.FileSaveAsClick(Sender: TObject);
var
  fmt2: TCppFormatter;
  inputStream, outputStream: TFileStream;
begin
  if FDocType <> dtNone then
  begin
    if SaveDialog1.Execute then
    begin
      inputStream := TFileStream.Create(FCurFilename, fmOpenRead);
      try
        outputStream := TFileStream.Create(SaveDialog1.FileName, fmCreate);
        case FDocType of
          dtCpp:
            case SaveDialog1.FilterIndex of
              1: CppToRTFStream(inputStream, outputStream);
              2: CppToHTMLStream(inputStream, outputStream);
              else
                raise Exception.Create('Invalid CPP Converter');
            end;
          dtPascal:
            case SaveDialog1.FilterIndex of
              1: PasToRTFStream(inputStream, outputStream);
              2: PasToHTMLStream(inputStream, outputStream);
              else
                raise Exception.Create('Invalid PAS Converter');
            end;
        end;

        outputStream.Free;

      finally
        inputStream.Free;
      end;
    end;
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  DocType := dtNone;
end;

{
  Changes the default extension of the save dialog based on the selected
  filter in the drop down list.
}
procedure TMainForm.SaveDialog1TypeChange(Sender: TObject);
begin
  case SaveDialog1.FilterIndex of
    1: SaveDialog1.DefaultExt := 'rtf';
    2: SaveDialog1.DefaultExt := 'html';
  end;
end;

end.
