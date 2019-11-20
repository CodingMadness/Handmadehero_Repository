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

  procedure CreateWindowSizedBuffer(const pixelBuffer: PPixelBuffer; const width: TMaxWidth; const height: TMaxHeight);
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
                              const width: TMaxWidth;
                              const height: TMaxHeight);
    begin
      pixelBuffer^.Height := height;
      pixelBuffer^.Width := width;
      pixelBuffer^.Area := TWindowArea(width * height);
      pixelBuffer^.TotalByteCount := TByteCount(pixelBuffer^.Area * PIXELSIZE);
      pixelBuffer^.Content := PPixel(GetMem(pixelBuffer^.TotalByteCount));
    end;

    procedure EnableGraphicProcessing(const pixelBuffer: PPixelBuffer;
                                      const width: TMaxWidth;
                                      const height: TMaxHeight);
    begin
      pixelBuffer^.INFO := default(BITMAPINFO);
      pixelBuffer^.INFO.bmiHeader.biSize := sizeOf(pixelBuffer^.INFO.bmiHeader);
      pixelBuffer^.INFO.bmiHeader.biWidth := Width;
      pixelBuffer^.INFO.bmiHeader.biHeight := (-1 * Height);
      pixelBuffer^.INFO.bmiHeader.biPlanes := 1;
      pixelBuffer^.INFO.bmiHeader.biBitCount := 32;
      pixelBuffer^.INFO.bmiHeader.biCompression := BI_RGB;
    end;

    procedure FreeIfNeeded(const pixelBuffer: PPixelBuffer);
    begin
     if pixelBuffer^.Content <> nil then
         dispose(pixelBuffer^.Content);
    end;
    {PRIVATE}


    {PUBLIC}
    procedure CreateWindowSizedBuffer(const pixelBuffer: PPixelBuffer; const width: TMaxWidth; const height: TMaxHeight);
    begin
      FreeIfNeeded(pixelBuffer);
      EnableGraphicProcessing(pixelBuffer, width, height);
      FillPixelBuffer(pixelBuffer, width, height);
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
