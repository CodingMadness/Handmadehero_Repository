program handmadehero;

{$mode objfpc}

uses
  SysUtils,
  Windows,
  GameWindow,
  Helper;

var
  pwnd: PWNDCLASSA = nil;

begin
  {Get the app-startup-frequency of the processor}
  QueryPerformanceFrequency(ClocksPerSecond);

  CreateWindowObject(pwnd);

  if RegisterWindow(pwnd) then
  begin
    ONE_GAMEHWND := DrawWindow(pwnd);

    if ONE_GAMEHWND = 0 then
    begin
      //log...
    end

    else
    begin
      FreeMemAndNil(pwnd);
      StartGameLoop;
    end;
  end;
end.
