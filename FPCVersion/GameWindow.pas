unit GameWindow;

  interface
      uses windows, sysutils;

      const
        MIN_WIDTH = 800;
        MIN_HEIGHT = 600;

      var
        ONE_GAMEHWND: HWND;

      type
        Int128 = Int128Rec;
        TMaxWidth  =  0..MIN_WIDTH;
        TMaxHeight =  0..MIN_HEIGHT;
        TWindowArea = 0..(MIN_WIDTH * MIN_HEIGHT);

        TWindowData = record
          Width: TMaxWidth;
          Height: TMaxHeight;
        end;

      procedure CreateWindowObject(var toAlloc: PWNDCLASS);
      function RegisterWindow(const wnd: PWNDCLASS): Bool;
      function DrawWindow(const wndObj: PWNDCLASS): HWND;
      procedure ProceedWin32MessagesFromAppQueue;
      procedure StartGameLoop;

  implementation
      uses
        GameInput,
        GameSound,
        GameGraphics;

      var
        RUNNING: BOOL;
        ONE_PIXELBUFFER: TPixelBuffer;
        ONE_SOUNDBUFFER, COPY: TSoundBuffer;
        ONE_GAMEWINDOW: Rect;
        ONE_DC: HDC;

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
              GetClientRect(window, @ONE_GAMEWINDOW);
              CreateWindowSizedBuffer(@ONE_PIXELBUFFER, TMaxWidth(ONE_GAMEWINDOW.Width), TMaxHeight(ONE_GAMEWINDOW.Height));
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
              ONE_DC := BeginPaint(window, @paintobj);
              WritePixelsToBuffer(@ONE_PIXELBUFFER, 0, 0);
              DrawPixelBuffer(ONE_DC, @ONE_PIXELBUFFER, @ONE_GAMEWINDOW);
              EndPaint(window, @paintobj);
            end;

            else
              {If we cant handle a message from the system, we send it back to the system and let it do what it needs to do}
              Result := DefWindowProc(window, message, wParam, lParam);
          end;
        end;

      procedure CreateWindowObject(var toAlloc: PWNDCLASS);
      begin
        toAlloc := PWNDCLASS(GetMem(sizeof(WNDCLASS)));
        toAlloc^ := default(WNDCLASS);
        toAlloc^.style := CS_VREDRAW or CS_HREDRAW or CS_OWNDC;
        toAlloc^.hInstance := GetModuleHandle(nil);
        toAlloc^.lpfnWndProc := WNDPROC(@MainWindowCallback);
        toAlloc^.lpszClassName := 'HMH_WindowClass';
        toAlloc^.lpszMenuName := 'Handmade Hero';
      end;

      function RegisterWindow(const wnd: PWNDCLASS): BOOL;
      begin
        Result := RegisterClass(wnd^) <> 0;
      end;

      function DrawWindow(const wndObj: PWNDCLASS): HWND;
      begin
        Result := CreateWindowEx(0, wndObj^.lpszClassName, wndObj^.lpszMenuName,
                                    WS_OVERLAPPEDWINDOW or WS_VISIBLE, CW_USEDEFAULT, CW_USEDEFAULT,
                                    CW_USEDEFAULT, CW_USEDEFAULT, 0, 0, wndObj^.hInstance, nil);
      end;

      procedure ProceedWin32MessagesFromAppQueue;
      var
        winMsg: MSG;
      begin
        winMsg := default(MSG);
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

        if EnableSoundProcessing(ONE_GAMEHWND) then
        begin
          CreateSoundBuffer(ONE_SOUNDBUFFER);
          {COPY := ONE_SOUNDBUFFER;}
        end;

        while RUNNING do
        begin
          ProceedWin32MessagesFromAppQueue;
          WriteSamplesToSoundBuffer(@ONE_SOUNDBUFFER);
          PlayTheSoundBuffer(@ONE_SOUNDBUFFER);
          WritePixelsToBuffer(@ONE_PIXELBUFFER, x, y);
          DrawPixelBuffer(ONE_DC, @ONE_PIXELBUFFER, @ONE_GAMEWINDOW);
          Inc(x);
          Inc(y);
        end;
      end;
end.
