unit GameGraphics;

{$modeswitch advancedrecords}

interface
  uses Windows, sysutils, GameWindow;

  const PIXELSIZE = 4;

  type
    TPixel = record
      Green, Red, Blue, PADDING: Byte;
    end;

    PPixel = ^TPixel;

    TByteCount = 0..(High(TWindowArea) * PIXELSIZE);

    TPixelBuffer = record
    public
      INFO: BITMAPINFO;
      Content: PPixel;
      Width: TMaxWidth;
      Height: TMaxHeight;
      Area: TWindowArea;
      TotalByteCount: TByteCount;
    end;

    PPixelBuffer = ^TPixelBuffer;

  procedure CreateWindowSizedBuffer(const pixelBuffer: PPixelBuffer; const wndWidth: TMaxWidth; const wndHeight: TMaxHeight);
  procedure WritePixelsToBuffer(const pixelBuffer: PPixelBuffer; const xOffset, yOffset: integer);
  procedure DrawPixelBuffer(const phdc: HDC; const pixelBuffer: PPixelBuffer; const gameWindowRect: PRect);

  implementation
    {PRIVATE}
    function CreatePixel(const r,g,b: integer): TPixel;
    begin
      {Assignment based on the endianess of the underlying machine}
      result.PADDING := 0;
      result.Green :=   Byte(b);
      result.Red   :=   Byte(g);
      result.Blue  :=   Byte(r);
    end;

    procedure FillPixelBuffer(const pixelBuffer: PPixelBuffer;
                              const windowData: TWindowData); inline;
    begin
      pixelBuffer^.Height := windowData.Height;
      pixelBuffer^.Width := windowData.Width;
      pixelBuffer^.Area := windowData.Width * windowData.Height;
      pixelBuffer^.TotalByteCount := pixelBuffer^.Area * PIXELSIZE;
      pixelBuffer^.Content := PPixel(VirtualAlloc(nil, pixelBuffer^.TotalByteCount, MEM_COMMIT, PAGE_READWRITE));
    end;

    procedure EnableGraphicProcessing(const pixelBuffer: PPixelBuffer;
                                      const windowData: TWindowData); inline;
    begin
      pixelBuffer^.INFO := default(BITMAPINFO);
      pixelBuffer^.INFO.bmiHeader.biSize := sizeOf(pixelBuffer^.INFO.bmiHeader);
      pixelBuffer^.INFO.bmiHeader.biWidth := windowData.Width;
      pixelBuffer^.INFO.bmiHeader.biHeight := (-1 * windowData.Height);
      pixelBuffer^.INFO.bmiHeader.biPlanes := 1;
      pixelBuffer^.INFO.bmiHeader.biBitCount := 32;
      pixelBuffer^.INFO.bmiHeader.biCompression := BI_RGB;
    end;
    {PRIVATE}


    {PUBLIC}
    procedure CreateWindowSizedBuffer(const pixelBuffer: PPixelBuffer; const wndWidth: TMaxWidth; const wndHeight: TMaxHeight); inline;
    var windowData: TWindowData;
    begin
      if pixelBuffer^.Content <> nil then
        writeLn('FREED MEMORY SUCCESSFULLY?  ' +
          BoolToStr(VirtualFree(pixelBuffer^.Content, 0, MEM_DECOMMIT)));

      windowData.Width := wndWidth;
      windowData.Height := wndHeight;

      EnableGraphicProcessing(pixelBuffer, windowData);
      FillPixelBuffer(pixelBuffer, windowData);
    end;

    procedure WritePixelsToBuffer(const pixelBuffer: PPixelBuffer; const xOffset, yOffset: integer);
    var
      rowNr, columnNr: integer;
      first, current: PPixel;
    begin
      first := pixelBuffer^.Content;

      for columnNr := 0 to (pixelBuffer^.Height - 1) do
      begin
        current := first;

        for rowNr := 0 to (pixelBuffer^.Width - 1) do
        begin
          current^ := CreatePixel((rowNr+xOffset), (columnNr+yOffset), (xOffset+yOffset));
          Inc(current);
        end;
        first += pixelBuffer^.Width;
      end;
    end;

    procedure DrawPixelBuffer(const phdc: HDC; const pixelBuffer: PPixelBuffer; const gameWindowRect: PRect);
    begin
      StretchDIBits(phdc, 0, 0, gameWindowRect^.Width, gameWindowRect^.Height,
                          0, 0, pixelBuffer^.Width, pixelBuffer^.Height,
                          pixelBuffer^.Content,
                          pixelBuffer^.INFO,
                          DIB_RGB_COLORS,
                          SRCCOPY);
    end;
    {PUBLIC}
end.
