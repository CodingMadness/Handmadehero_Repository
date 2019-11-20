unit GameWindow;

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
        TWindowArea = 0..(MAX_WIDTH * MAX_HEIGHT);

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
        {LazLogger,}
        Helper;

      var
        RUNNING: boolean;
        INPUT_PIXELBUFFER: TPixelBuffer;
        ONE_SOUNDBUFFER: TSoundBuffer;
        OUTPUT_GAMEWINDOW: Rect;
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
              GetClientRect(window, @OUTPUT_GAMEWINDOW);
              CreateWindowSizedBuffer(@INPUT_PIXELBUFFER, TMaxWidth(OUTPUT_GAMEWINDOW.Width), TMaxHeight(OUTPUT_GAMEWINDOW.Height));
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

            WM_PAINT:
            begin
              ONE_DC := BeginPaint(window, @paintobj);
              WritePixelsToBuffer(@INPUT_PIXELBUFFER, 0, 0);
              DrawPixelBuffer(ONE_DC, @INPUT_PIXELBUFFER, @OUTPUT_GAMEWINDOW);
              EndPaint(window, @paintobj);
            end;

            else
              {If we cant handle a message from the system, we send it back to the system and let it do what it needs to do}
              Result := DefWindowProc(window, message, wParam, lParam);
          end;
        end;

      procedure CreateWindowObject(var toAlloc: PWNDCLASSA);
      begin
        toAlloc := PWNDCLASSA(GetMem(sizeof(WNDCLASSA)));
        toAlloc^ := default(WNDCLASSA);
        toAlloc^.style := CS_VREDRAW or CS_HREDRAW or CS_OWNDC;
        toAlloc^.hInstance := GetModuleHandle(nil);
        toAlloc^.lpfnWndProc := WNDPROC(@MainWindowCallback);
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
        x, y: integer;
        lastCounter, endCounter, timeElapsed : TLargeInteger;
        millisecPerFrame: TLargeInteger;
        fps: TLargeInteger;

        lastCycleCount, endCycleCount, cyclesElapsed,megaCyclesElapsed: QWORD;
      begin
        RUNNING := true;
        x := 0;
        y := 0;
        lastCycleCount := 0;
        endCycleCount := 0;

        if EnableSoundProcessing(ONE_GAMEHWND) then
          CreateSoundBuffer(ONE_SOUNDBUFFER);

       // {Start measuring time before the GameLoop starts..}
       // QueryPerformanceCounter(lastCounter);

        {$Region 1.Frame}
        {Start measuring time before the GameLoop starts..}
        lastCycleCount := _rdtsc;
        QueryPerformanceCounter(lastCounter);

        while RUNNING do
        begin
          ProceedWin32MessagesFromAppQueue;

          {......................................}
          WriteSamplesToSoundBuffer(@ONE_SOUNDBUFFER);
          PlayTheSoundBuffer(@ONE_SOUNDBUFFER);

          {......................................}
          WritePixelsToBuffer(@INPUT_PIXELBUFFER, x, y);
          DrawPixelBuffer(ONE_DC, @INPUT_PIXELBUFFER, @OUTPUT_GAMEWINDOW);
          Inc(x);
          Inc(y);

          {
            {Start measuring time right after the GameLoop finishes}
            endCycleCount := _rdtsc;
            QueryPerformanceCounter(endCounter);

            cyclesElapsed := QWORD(endCycleCount - lastCycleCount);
            timeElapsed := endCounter - lastCounter;

            millisecPerFrame := (1000*timeElapsed) div ClocksPerSecond;
            fps := ClocksPerSecond div timeElapsed;
            megaCyclesElapsed := cyclesElapsed div (1000 * 1000);

            writeln(StdErr, 'Milliseconds/Frame: ', millisecPerFrame, ' ||| FPS:  ', fps, '|||  MHZ: ' ,megaCyclesElapsed);
            writeln;

            lastCounter := endCounter;
            lastCycleCount := endCycleCount;
            {......................................}
          }
        end;
       {$Region 1.Frame}
      end;
end.
