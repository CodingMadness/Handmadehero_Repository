program handmadehero;

{$mode objfpc}

uses
  SysUtils,
  Windows,
  GameWindow;

var
  pwnd: PWNDCLASS = nil;

begin
  CreateWindowObject(pwnd);

  if RegisterWindow(pwnd) then
  begin
    ONE_GAMEHWND := DrawWindow(pwnd); //this line is actually okm comment out just for test

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
