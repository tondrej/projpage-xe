program Project1;

{$APPTYPE CONSOLE}

uses
  SysUtils;

procedure Main;
begin
  Writeln('Hello, world!');
end;

begin
  try
    Main;
  except
    on E: Exception do
    begin
      ExitCode := 1;
      Writeln(Format('[%s] %s', [E.ClassName, E.Message]));
    end;
  end;
end.
