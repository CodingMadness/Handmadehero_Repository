unit GameWindow;

{$mode objfpc}
  interface
      uses windows;

      const
        MIN_WIDTH = 800;
        MIN_HEIGHT = 600;
        MAX_WIDTH = 3840;
        MAX_HEIGHT = 1200;

      var
        ONE_GAMEHWND: HWND;

      type
        TMaxWidth  =  MIN_WIDTH..MAX_WIDTH;
        TMaxHeight =  MIN_HEIGHT..MAX_HEIGHT;

        THeightRange = 0..MAX_HEIGHT-1;
        TWidthRange  = 0..MAX_WIDTH-1;

        TWindowArea = MIN_WIDTH * MIN_HEIGHT..MAX_WIDTH * MAX_HEIGHT;

      procedure CreateWindowObject(var toAlloc: PWNDCLASSA);
      function RegisterWindow(const wnd: PWNDCLASSA): boolean;
      function DrawWindow(const wndObj: PWNDCLASSA): HWND;
      procedure ProceedWin32MessagesFromAppQueue;
      procedure StartGameLoop;

  implementation
      uses
        GameInput,
        GameSound,
        GameGraphics,
        Helper;

      var
        RUNNING: boolean;
        WIN32_BITMAPBUFFER: TPixelBuffer;
        ONE_SOUNDBUFFER: TSoundBuffer;
        OUTPUT_GAMEWINDOW: Rect;
        ONE_DC: HDC;


      function MAINWINDOWCALLBACK(const processID: HWND; const message: UINT;
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
              CreateWindowSizedBuffer(@WIN32_BITMAPBUFFER, 1200, 800);
              //WritePixelsToBuffer(@WIN32_BITMAPBUFFER); // just a small test
            end;

            WM_QUIT: RUNNING := false;

            WM_CLOSE:
            begin
              //TODO:(Shpend): Handle this as an information to the user
              RUNNING := false;
            end;

            WM_DESTROY:
            begin
              //TODO:(Shpend): Handle this as error
              RUNNING := false;
            end;

            //We constantly force our Window to paint itself after the other mgs's were proceed
            WM_PAINT:
            begin
              ONE_DC := BeginPaint(processID, @paintobj);
              WritePixelsToBuffer(@WIN32_BITMAPBUFFER, 100, tcGreen);
              GetClientRect(processID, OUTPUT_GAMEWINDOW);
              DrawPixelBuffer(ONE_DC, @WIN32_BITMAPBUFFER, OUTPUT_GAMEWINDOW.Width, OUTPUT_GAMEWINDOW.Height);
              EndPaint(processID, @paintobj);
            end;

            else
              {If we cant longint a message from the system, we send it back to the system and let it do what it needs to do}
              Result := DefWindowProc(processID, message, wParam, lParam);
          end;
        end;
{-----------------------------------------------------------------------------}



      procedure CreateWindowObject(var toAlloc: PWNDCLASSA);
      begin
        toAlloc := PWNDCLASSA(GetMem(sizeof(WNDCLASSA)));
        toAlloc^ := default(WNDCLASSA);
        toAlloc^.style := CS_VREDRAW or CS_HREDRAW or CS_OWNDC;
        toAlloc^.hInstance := GetModuleHandle(nil);
        toAlloc^.lpfnWndProc := WNDPROC(@MAINWINDOWCALLBACK);
        toAlloc^.lpszClassName := 'HMH_WindowClass';
        toAlloc^.lpszMenuName := 'Handmade Hero';
      end;

      function RegisterWindow(const wnd: PWNDCLASSA): boolean;
      begin
        Result := RegisterClassA(wnd^) <> 0;
      end;

      function DrawWindow(const wndObj: PWNDCLASSA): HWND;
      begin
        Result := CreateWindowExA(0, wndObj^.lpszClassName, wndObj^.lpszMenuName,
                                    WS_OVERLAPPEDWINDOW or WS_VISIBLE, CW_USEDEFAULT, CW_USEDEFAULT,
                                    CW_USEDEFAULT, CW_USEDEFAULT, 0, 0, wndObj^.hInstance, nil);
      end;

      procedure ProceedWin32MessagesFromAppQueue;
      var
        winMsg: MSG;
      begin
        winMsg := default(MSG);

        {Removes 1 Message from the the app-thread messagequeue}
        while (PeekMessage(@winMsg, 0, 0, 0, PM_REMOVE)) do
        begin
          TranslateMessage(@winMsg);
          DispatchMessage(@winMsg);
        end;
      end;

      procedure StartGameLoop;
      var
        x: integer;
        currColor: TColor;
      begin
        RUNNING := true;
        x := 0;

        currColor := low(currColor);

        if EnableSoundProcessing(ONE_GAMEHWND) then
        begin
          CreateSoundBuffer(ONE_SOUNDBUFFER);
          PlayTheSoundBuffer(@ONE_SOUNDBUFFER);
        end;

        //StartSpeedMeasureBeforeGameLogicBegins;

        while RUNNING do
        begin
          ProceedWin32MessagesFromAppQueue;

          WriteSamplesToSoundBuffer(@ONE_SOUNDBUFFER);

          WritePixelsToBuffer(@WIN32_BITMAPBUFFER, x, currColor);
          DrawPixelBuffer(ONE_DC, @WIN32_BITMAPBUFFER, TMaxWidth(OUTPUT_GAMEWINDOW.Width), TMaxHeight(OUTPUT_GAMEWINDOW.Height));

          x+=1;

          currColor := GetRndColor;

          //StartSpeedMeasureAfterLoopGameLogicEnd;

          //OutputAllSpeedMeasurements;
        end;
      end;
end.
