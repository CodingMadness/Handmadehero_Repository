unit Bitmap;

{$modeswitch advancedrecords}

interface
  uses Windows, GLOBAL, sysutils;


   type
    TPixel = record
      Green, Red, RESERVED, Blue: Byte;
    end;

    PPixel = ^TPixel;

    TPixelBuffer = record
    public
      INFO: BITMAPINFO;
      Height: integer;
      Width: integer;
      Content: ^TPixel;
      const PIXELSIZE = 4;
    (*
      function Initiailzed: boolean;
      begin
         result := (INFO.Defined and (Content <> nil) and ((Width >= MIN_WIDTH) and (Height >= MIN_HEIGHT) and (Width >= Height)));
      end;
    *)
    end;

    PPixelBuffer = ^TPixelBuffer;

  procedure CreateWindowSizedBuffer(const buffer: PPixelBuffer; const gameWindowWidth, gameWindowHeight: integer);
  procedure DisplayBufferInWindow(const phdc: HDC; const buffer: PPixelBuffer; const gameWindowRect: PRect);
  procedure WritePixelsToBuffer(const buffer: PPixelBuffer; const xOffset, yOffset: integer);

implementation
  {var cntr:qword = 0;}

  function CreatePixel(const r,g,b: integer): TPixel;
  begin
    //strange assignment because of Endianess!
    result.RESERVED := Byte(g);
    result.Green := Byte(b);
    result.Red := Byte(r);
    result.Blue := 0;
  end;

  procedure CreateWindowSizedBuffer(const buffer: PPixelBuffer; const gameWindowWidth, gameWindowHeight: integer);
  var
    bmMemorySize: longword;
  begin
    if buffer^.Content <> nil then
    begin
      writeLn('FREED MEMORY SUCCESSFULLY?  ' +
        BoolToStr(VirtualFree(buffer^.Content, 0, MEM_DECOMMIT)));
    end;

    //NOTE(Shpend): The "-gameWindowHeight" tells windows, to treat the window
    //as Top-Down, means, the pointer of the first pixel starts at the top-left-side
    buffer^.INFO.bmiHeader.biSize := sizeOf(buffer^.INFO.bmiHeader);
    buffer^.INFO.bmiHeader.biWidth := gameWindowWidth;
    buffer^.INFO.bmiHeader.biHeight := -gameWindowHeight;
    buffer^.INFO.bmiHeader.biPlanes := 1;
    buffer^.INFO.bmiHeader.biBitCount := 32;
    buffer^.INFO.bmiHeader.biCompression := BI_RGB;

    buffer^.Width := gameWindowWidth;
    buffer^.Height := gameWindowHeight;

    bmMemorySize := buffer^.PixelSize * (gameWindowWidth * gameWindowHeight);
    buffer^.Content := PPixel(VirtualAlloc(nil, bmMemorySize, MEM_COMMIT, PAGE_READWRITE));
  end;

  procedure WritePixelsToBuffer(const buffer: PPixelBuffer; const xOffset, yOffset: integer);
  var
    rowNr, columnNr: integer;
    first, current: PPixel;
  begin
    first := buffer^.Content;

    for columnNr := 0 to (buffer^.Height - 1) do
    begin
      current := first;

      for rowNr := 0 to (buffer^.Width - 1) do
      begin
        current^ := CreatePixel((rowNr+xOffset), (columnNr+yOffset), (xOffset+yOffset));
        Inc(current);
      end;
      first += buffer^.Width;
    end;
  end;

  procedure DisplayBufferInWindow(const phdc: HDC; const buffer: PPixelBuffer; const gameWindowRect: PRect);
  begin
    StretchDIBits(phdc, 0, 0, gameWindowRect^.Width, gameWindowRect^.Height,
                        0, 0, buffer^.Width, buffer^.Height,
                        buffer^.Content,
                        buffer^.INFO,
                        DIB_RGB_COLORS,
                        SRCCOPY);
  end;

end.
