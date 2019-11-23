unit GameGraphics;

{$modeswitch advancedrecords}

interface
  uses Windows, sysutils, GameWindow;

  const PIXELSIZE = 4;

  type
    TPixel = record
      Blue, Green, Red, PADDING: Byte;
    end;

    PPixel = ^TPixel;

    TTotalPixelByteLength = 0..(High(TWindowArea) * PIXELSIZE);

    TPixelBuffer = record
    public
      INFO: BITMAPINFO;
      Content: PPixel;
      Width: TMaxWidth;
      Height: TMaxHeight;
      Area: TWindowArea;
      TotalPixelByteLength: TTotalPixelByteLength;
    end;

    PPixelBuffer = ^TPixelBuffer;

  procedure CreateWindowSizedBuffer(const pixelBuffer: PPixelBuffer; const width: TMaxWidth; const height: TMaxHeight);
  procedure WritePixelsToBuffer(const pixelBuffer: PPixelBuffer; const xOffset, yOffset: integer);
  procedure DrawPixelBuffer(const phdc: HDC; const pixelBuffer: PPixelBuffer; const gameWindowWidth:TMaxWidth; gameWindowHeight: TMaxHeight);

  implementation
    {PRIVATE}
    function CreatePixel(const r, g, b: integer): TPixel;
    begin
      result.Red      := Byte(r);
      result.Green    := Byte(g);
      result.Blue     := Byte(b);

      result.PADDING  := 0;
    end;

    procedure AllocatePixelBuffer(const pixelBuffer: PPixelBuffer;
                                  const width: TMaxWidth;
                                  const height: TMaxHeight);
    begin
      pixelBuffer^.Height := height;
      pixelBuffer^.Width := width;
      pixelBuffer^.Area := TWindowArea(width * height);
      pixelBuffer^.TotalPixelByteLength := TTotalPixelByteLength(pixelBuffer^.Area * PIXELSIZE);
      pixelBuffer^.Content := PPixel(VirtualAlloc(nil, pixelBuffer^.TotalPixelByteLength, MEM_COMMIT, PAGE_READWRITE));
    end;

    procedure DefineBitmapLayout(const pixelBuffer: PPixelBuffer;
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

    procedure FreePixelBufferIfNeedBe(const pixelBuffer: PPixelBuffer);
    begin
     if pixelBuffer^.Content <> nil then
         VirtualFree(pixelBuffer^.Content, 0, MEM_RELEASE);
    end;
    {PRIVATE}


    {PUBLIC}
    procedure CreateWindowSizedBuffer(const pixelBuffer: PPixelBuffer; const width: TMaxWidth; const height: TMaxHeight);
    begin
      FreePixelBufferIfNeedBe(pixelBuffer);
      DefineBitmapLayout(pixelBuffer, width, height);
      AllocatePixelBuffer(pixelBuffer, width, height);
    end;

    procedure WritePixelsToBuffer(const pixelBuffer: PPixelBuffer; const xOffset, yOffset: integer);
    var
      rowNr, columnNr: integer;
      currentRow, currentColumn: PPixel;
    begin
      currentRow := pixelBuffer^.Content;

      for columnNr := 0 to (pixelBuffer^.Height - 1) do
      begin
        currentColumn := currentRow;

        for rowNr := 0 to (pixelBuffer^.Width - 1) do
        begin
          currentColumn^ := CreatePixel(255,0 ,0);
          currentColumn += 1; //move pixelpointer to the right by sizeof(TPixel);
        end;

        currentRow += pixelBuffer^.Width;
      end;

    end;

    procedure DrawPixelBuffer(const phdc: HDC; const pixelBuffer: PPixelBuffer; const gameWindowWidth: TMaxWidth; gameWindowHeight: TMaxHeight);
    begin
      //Define Aspect Ratio
      //TODO(Shpend): Play abit with Stretchmode
      StretchDIBits(phdc, 0, 0, gameWindowWidth, gameWindowHeight,
                          0, 0, pixelBuffer^.Width, pixelBuffer^.Height,
                          pixelBuffer^.Content,
                          pixelBuffer^.INFO,
                          DIB_RGB_COLORS,
                          SRCCOPY);
    end;
    {PUBLIC}
end.
