unit GameWindow;

interface

{------------------------------------------------------------------------------}
uses Bitmap, GameInput, GameSound, GLOBAL, Windows;

procedure AllocWindow(var toAlloc: PWNDCLASS);
function RegisterWindow(const wnd: PWNDCLASS): Bool;
function DrawWindow(const wndObj: PWNDCLASS): HWND;
procedure ProceedWin32Messages;
procedure StartGameLoop;
{------------------------------------------------------------------------------}


implementation

var
  CURRENTBUFFER: TPixelBuffer;
  CURRENTGAMEWINDOW: Rectangle;
  CurrentSoundBuffer: TSoundBuffer;
  RUNNING: boolean;
  DC: HDC;

function MainWindowCallback(const window: HWND; const message: UINT;
  const wParam: WPARAM; const lParam: LPARAM): LRESULT;
var
  paintobj: PAINTSTRUCT;
begin
  case message of
    WM_KEYUP:
    begin
      if IsKeyPressedOnce(wParam, lParam, 'W') then
        writeLn('W');

      if IsKeyPressedOnce(wParam, lParam, 'A') then
        writeLn('A');

      if IsKeyPressedOnce(wParam, lParam, 'S') then
        writeLn('S');

      if IsKeyPressedOnce(wParam, lParam, 'D') then
        writeLn('D');
    end;

    WM_SIZE:
    begin
      GetClientRect(window, @CURRENTGAMEWINDOW);
      CreateWindowSizedBuffer(@CURRENTBUFFER, CURRENTGAMEWINDOW.Width,
        CURRENTGAMEWINDOW.Height);
    end;

    WM_ACTIVATEAPP:
    begin
      writeLn('WM_ACTIVATE');
    end;

    WM_QUIT: RUNNING := False;

    WM_CLOSE:
    begin
      //TODO:(Shpend): Handle this as an information to the user
      RUNNING := False;
    end;

    WM_DESTROY:
    begin
      //TODO:(Shpend): Handle this as error
      RUNNING := False;
    end;

    WM_PAINT:
    begin
      DC := BeginPaint(window, @paintobj);
      WritePixelsToBuffer(@CURRENTBUFFER, 0, 0);
      DisplayBufferInWindow(DC, @CURRENTBUFFER, @CURRENTGAMEWINDOW);
      EndPaint(window, @paintobj);
    end;

    else
      {If we cant handle a message from the system, we send it back to the system and let it do what it needs to do}
      Result := DefWindowProc(window, message, wParam, lParam);
  end;
end;

procedure AllocWindow(var toAlloc: PWNDCLASS);
begin
  toAlloc := PWNDCLASS(GetMem(1 * sizeof(WNDCLASS)));
  ZeroMemory(toAlloc, sizeof(WNDCLASS));
  toAlloc^.style := CS_VREDRAW or CS_HREDRAW or CS_OWNDC;
  toAlloc^.hInstance := GetModuleHandle(nil);
  toAlloc^.lpfnWndProc := WNDPROC(@MainWindowCallback);
  toAlloc^.lpszClassName := 'HMH_WindowClass';
  toAlloc^.lpszMenuName := 'Handmade Hero';
end;

function RegisterWindow(const wnd: PWNDCLASS): Bool;
begin
  Result := RegisterClass(wnd^) <> 0;
end;

function DrawWindow(const wndObj: PWNDCLASS): HWND;
begin
  Result := CreateWindowEx(0, wndObj^.lpszClassName, wndObj^.lpszMenuName,
    WS_OVERLAPPEDWINDOW or WS_VISIBLE, CW_USEDEFAULT, CW_USEDEFAULT,
    CW_USEDEFAULT, CW_USEDEFAULT, 0, 0, wndObj^.hInstance, nil);
end;

procedure ProceedWin32Messages;
var
  winMsg: Win32Message;
begin
  winMsg := default(Win32Message);
  RUNNING := True;

  {Removes 1 Message from the the app-thread messagequeue}
  while (PeekMessage(@winMsg, 0, 0, 0, PM_REMOVE)) do
  begin
    TranslateMessage(@winMsg);
    DispatchMessage(@winMsg);
  end;
end;

procedure StartGameLoop;
var
  x, y: integer;
begin
  RUNNING := True;
  x := 0;
  y := 0;

  EnableSoundProcessing(GAMEHWND);
  CreateWriteableSoundBuffer(CurrentSoundBuffer);
  //WriteSamplesToSoundBuffer(@CurrentSoundBuffer);
  PlayTheSoundBuffer(@CurrentSoundBuffer);

  while RUNNING do
  begin
    ProceedWin32Messages;
    writeln('start the animation');
    WriteSamplesToSoundBuffer(@CurrentSoundBuffer);
    WritePixelsToBuffer(@CURRENTBUFFER, x, y);
    DisplayBufferInWindow(DC, @CURRENTBUFFER, @CURRENTGAMEWINDOW);
    Inc(x);
    Inc(y);
  end;
end;

end.
