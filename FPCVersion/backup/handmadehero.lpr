program handmadehero;

uses
  SysUtils,
  Windows,
  GameWindow,
  Global;

var
  pwnd: PWNDCLASS = nil;

begin
  AllocWindow(pwnd);

  if RegisterWindow(pwnd) then
  begin
    GAMEHWND := DrawWindow(pwnd);

    if GAMEHWND = 0 then
    begin
      //log...
    end

    {Proceed all upcoming messages from system and thread queues}
    else
    begin
      FreeMemAndNil(pwnd);
      StartGameLoop;
    end;
  end;
end.
