unit frmMain;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Classes, Graphics,
  Controls, Forms, Dialogs,
  StdCtrls, ComCtrls, Buttons, ExtCtrls, Menus, ToolWin, ImgList;

type
  TDocumentType = (dtNone, dtCpp, dtPascal);

  TMainForm = class(TForm)
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    MainMenu1: TMainMenu;
    FileMenu: TMenuItem;
    FileOpen: TMenuItem;
    FileExit: TMenuItem;
    RichEdit1: TMemo;
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
    procedure PasToRTFClick(Sender: TObject);
    procedure PasToHTMLClick(Sender: TObject);
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
    property DocType: TDocumentType read FDocType write SetDocType;
    property CurFileName: string read FCurFileName write SetCurFileName;
  public
    procedure OpenCppFile(const FileName: string);
    procedure OpenPasFile(const FileName: string);
    procedure OpenFile(const FileName: string);
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

procedure TMainForm.PasToRTFClick(Sender: TObject);
var
  stream1, stream2: TFileStream;
  fmt: TPasToRTF;
begin
  if OpenDialog1.Execute then
  begin
    SaveDialog1.DefaultExt := 'rtf';
    SaveDialog1.Filter := 'Rich Text Format|*.rtf|All files|*.*';
    if SaveDialog1.Execute then
    begin
      stream1 := TFileStream.Create(OpenDialog1.FileName, fmOpenRead);
      stream2 := TFileStream.Create(SaveDialog1.FileName, fmCreate);
      fmt := TPasToRTF.Create;
      fmt.FormatStream(stream1, stream2);
      fmt.Free;
      stream2.Free;
      stream1.Free;
    end;
  end;
end;

procedure TMainForm.PasToHTMLClick(Sender: TObject);
var
  stream1, stream2: TFileStream;
  fmt: TPasToHTML;
begin
  if OpenDialog1.Execute then
  begin
    SaveDialog1.DefaultExt := 'html';
    SaveDialog1.Filter := 'HTML Document|*.html|All files|*.*';
    if SaveDialog1.Execute then
    begin
      stream1 := TFileStream.Create(OpenDialog1.FileName, fmOpenRead);
      stream2 := TFileStream.Create(SaveDialog1.FileName, fmCreate);
      fmt := TPasToHTML.Create;
      fmt.FormatStream(stream1, stream2);
      fmt.Free;
      stream2.Free;
      stream1.Free;
    end;
  end;
end;

procedure TMainForm.OpenCppFile(const FileName: string);
var
  stream1: TFileStream;
  stream2: TMemoryStream;
  fmt: TCppToRTF;
begin
  stream1 := TFileStream.Create(FileName, fmOpenRead);
  stream2 := TMemoryStream.Create;
  fmt := TCppToRTF.Create;
  fmt.FormatStream(stream1, stream2);
  fmt.Free;
  stream1.Free;
  stream2.seek(0, 0);
  RichEdit1.Lines.LoadFromStream(stream2);
  stream2.Free;
  DocType := dtCpp;
  CurFileName := FileName;
end;

procedure TMainForm.OpenPasFile(const FileName: string);
var
  stream1: TFileStream;
  stream2: TMemoryStream;
  fmt: TPasToRTF;
begin
  stream1 := TFileStream.Create(FileName, fmOpenRead);
  stream2 := TMemoryStream.Create;
  fmt := TPasToRTF.Create;
  fmt.FormatStream(stream1, stream2);
  fmt.Free;
  stream1.Free;
  stream2.seek(0, 0);
  RichEdit1.Lines.LoadFromStream(stream2);
  stream2.Free;
  DocType := dtPascal;
  CurFileName := FileName;
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

procedure TMainForm.ToolsPrefClick(Sender: TObject);
begin
end;

procedure TMainForm.HelpAboutClick(Sender: TObject);
begin
  AboutForm.ShowModal;
end;

procedure TMainForm.OpenFile(const FileName: string);
var
  s: string;
begin
  s := ExtractFileExt(FileName);
  if (AnsiSameText(s, '.cpp') or AnsiSameText(s, '.c') or AnsiSameText(s, '.h')) then
    OpenCppFile(FileName)
  else if (AnsiSameText(s, '.pas') or AnsiSameText(s, '.dpr')) then
    OpenPasFile(FileName)
  else
    MessageDlg('Αυτή η μορφή δεν υποστηρίζεται (' + s + ').', mtError, [mbOK], 0);
end;

procedure TMainForm.FileSaveAsClick(Sender: TObject);
var
  fmt1: TPasFormatter;
  fmt2: TCppFormatter;
  stream1, stream2: TFileStream;
begin
  if FDocType <> dtNone then
  begin
    if SaveDialog1.Execute then
    begin
      stream1 := TFileStream.Create(FCurFilename, fmOpenRead);
      stream2 := TFileStream.Create(SaveDialog1.FileName, fmCreate);
      case FDocType of
        dtCpp:
          case SaveDialog1.FilterIndex of
            1:
            begin
              fmt2 := TCppToRTF.Create;
              fmt2.FormatStream(stream1, stream2);
              fmt2.Free;
            end;
            2:
            begin
              fmt2 := TCppToHTML.Create;
              fmt2.FormatStream(stream1, stream2);
              fmt2.Free;
            end;
            else
              raise Exception.Create('Invalid CPP Converter');
          end;
        dtPascal:
          case SaveDialog1.FilterIndex of
            1:
            begin
              fmt1 := TPasToRTF.Create;
              fmt1.FormatStream(stream1, stream2);
              fmt1.Free;
            end;
            2:
            begin
              fmt1 := TPasToHTML.Create;
              fmt1.FormatStream(stream1, stream2);
              fmt1.Free;
            end;
            else
              raise Exception.Create('Invalid PAS Converter');
          end;
      end;

      stream2.Free;
      stream1.Free;
    end;
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  DocType := dtNone;
end;

procedure TMainForm.SaveDialog1TypeChange(Sender: TObject);
begin
  case SaveDialog1.FilterIndex of
    1: SaveDialog1.DefaultExt := 'rtf';
    2: SaveDialog1.DefaultExt := 'html';
  end;
end;

end.
