(*

MIT License

Copyright (c) 2021 Ondrej Kelle

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*)

unit ProjPageClasses;

interface

implementation

uses
  Windows, Classes, SysUtils, Forms, ToolsApi;

type
  IURLModule = interface(IOTAModuleData)
  ['{9D215B02-6073-45DC-B007-1A2DBCE2D693}']
    function GetURL: string;
    procedure SetURL(const URL: string);
    property URL: string read GetURL write SetURL;
  end;

  TOpenNewURLModule = procedure(const URL: string; EditorForm: TCustomForm);

  TIDENotifier = class(TNotifierObject, IOTAIDENotifier)
  private
    { IOTAIDENotifier }
    procedure AfterCompile(Succeeded: Boolean);
    procedure BeforeCompile(const Project: IOTAProject; var Cancel: Boolean);
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean);

    procedure CheckActiveProject;
  end;

function FindURLModule(const FileName: string): IURLModule;
var
  ModuleServices: IOTAModuleServices;
  I: Integer;
  Module: IOTAModule;
begin
  Result := nil;
  if not BorlandIDEServices.GetService(IOTAModuleServices, ModuleServices) then
    Exit;

  for I := 0 to ModuleServices.ModuleCount - 1 do
  begin
    Module := ModuleServices.Modules[I];
    if SameText(ExtractFileName(FileName), Module.FileName) and Supports(Module, IURLModule, Result) and
      SameText(Result.URL, FileName) then
        Exit;
  end;

  Result := nil;
end;

procedure OpenHtmlFile(const FileName: string);
const
  SStartPageIDE = 'startpageide150.bpl';
  SOpenNewURLModule = '@Urlmodule@OpenNewURLModule$qqrx20System@UnicodeStringp22Editorform@TEditWindow';
var
  FileUrl: string;
  AlreadyOpenModule: IURLModule;
  EditWindow: INTAEditWindow;
  StartPageLib: HMODULE;
  OpenNewURLModule: TOpenNewURLModule;
begin
  FileUrl := 'file://' + FileName;
  AlreadyOpenModule := FindURLModule(FileName);
  if Assigned(AlreadyOpenModule) then
  begin
    AlreadyOpenModule.URL := FileUrl;
    (AlreadyOpenModule as IOTAModule).Show;
  end
  else
  begin
    EditWindow := (BorlandIDEServices as INTAEditorServices).TopEditWindow;
    if not Assigned(EditWindow) or not Assigned(EditWindow.Form) then
      Exit;

    StartPageLib := GetModuleHandle(SStartPageIDE);
    if StartPageLib = 0 then
      Exit;

    OpenNewURLModule := GetProcAddress(StartPageLib, SOpenNewURLModule);
    if @OpenNewURLModule <> nil then
      OpenNewURLModule(FileUrl, EditWindow.Form);
  end;
end;

{ TIDENotifier private: IOTAIDENotifier }

procedure TIDENotifier.AfterCompile(Succeeded: Boolean);
begin
  // do nothing
end;

procedure TIDENotifier.BeforeCompile(const Project: IOTAProject; var Cancel: Boolean);
begin
  // do nothing
end;

procedure TIDENotifier.FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean);
begin
  case NotifyCode of
    ofnActiveProjectChanged:
      CheckActiveProject;
  end;
end;

{ TIDENotifier private }

procedure TIDENotifier.CheckActiveProject;
var
  ModuleServices: IOTAModuleServices;
  ActiveProject: IOTAProject;
  I: Integer;
  ModuleInfo: IOTAModuleInfo;
begin
  if not BorlandIDEServices.GetService(IOTAModuleServices, ModuleServices) then
    Exit;

  ActiveProject := ModuleServices.GetActiveProject;
  if not Assigned(ActiveProject) then
    Exit;

  for I := 0 to ActiveProject.GetModuleCount - 1 do
  begin
    ModuleInfo := ActiveProject.GetModule(I);
    if SameText('index.htm', ExtractFileName(ModuleInfo.FileName)) or
      SameText('index.html', ExtractFileName(ModuleInfo.FileName)) then
    begin
      OpenHtmlFile(ModuleInfo.FileName);
      Break;
    end;
  end;
end;

var
  NotifierIndex: Integer = -1;

procedure InitializeNotifier;
var
  Services: IOTAServices;
begin
  if not BorlandIDEServices.GetService(IOTAServices, Services) then
    Exit;
  NotifierIndex := Services.AddNotifier(TIDENotifier.Create);
end;

procedure FinalizeNotifer;
var
  Services: IOTAServices;
begin
  if (NotifierIndex = -1) or not BorlandIDEServices.GetService(IOTAServices, Services) then
    Exit;
  Services.RemoveNotifier(NotifierIndex);
  NotifierIndex := -1;
end;

initialization
  InitializeNotifier;

finalization
  FinalizeNotifer;

end.
