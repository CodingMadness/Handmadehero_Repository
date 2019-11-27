unit GameGraphics;

{$modeswitch advancedrecords}
{$mode objfpc}

interface
  uses Windows, sysutils, GameWindow, helper;

  const PIXELSIZE = 4;

  type
    TPixel = record
     //DO NOT CHANGE THE ORDER,TO MAINTAIN PROPER ENDIAN REPRESENTATION!
      Blue, Green, Red, PADDING: Byte;
    end;

    PPixel = ^TPixel;

    TTotalPixelByteLength = 0..(High(TWindowArea) * PIXELSIZE);

    TPixelBuffer = record
      INFO: BITMAPINFO;
      Content: PPixel;
      Width: TMaxWidth;
      Height: TMaxHeight;
      Area: TWindowArea;
      TotalPixelByteLength: TTotalPixelByteLength;
    end;

    PPixelBuffer = ^TPixelBuffer;


  procedure CreateWindowSizedBuffer(const pixelBuffer: PPixelBuffer; const width: TMaxWidth; const height: TMaxHeight);
  procedure WritePixelsToBuffer(const pixelBuffer: PPixelBuffer; const rowsPerColor: integer; const color: TColor);
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
    procedure CreateWindowSizedBuffer(const pixelBuffer: PPixelBuffer;
                                      const width: TMaxWidth; const height: TMaxHeight);
    begin
      FreePixelBufferIfNeedBe(pixelBuffer);
      DefineBitmapLayout(pixelBuffer, width, height);
      AllocatePixelBuffer(pixelBuffer, width, height);
    end;


    procedure WritePixelsToBuffer(const pixelBuffer: PPixelBuffer; const rowsPerColor: integer; const color: TColor);
        procedure Write_N_RowsOfColor(rndColor: TColor; const rowsPerColor: TMaxHeight);
        label FIRSTTIME;
        var
          purePixel: TPixel = (Blue:0; Green:0; Red:0; PADDING:0);

        const
          maxRowCountPerProc: THeightRange = 0;
          xOffset: TWidthRange = 0;
          yOffset: THeightRange = 0;
          currCell: PPixel = nil;
          nextRow: PPixel = nil;

        begin
          //check if this procedure gets called for the first time,
          //since "yOffset" is only 0 at the very beginning!;
          FIRSTTIME:
          if yOffset = 0 then
          begin
            xOffset := 0;
            yOffset := 0;
            nextRow := pixelBuffer^.Content; //start at: row--->{0;0}
            maxRowCountPerProc := rowsPerColor-1; //rowsPerColor-1 because we start from 0, so 0..max-1
          end

          else if yOffset > 0 then
          begin
           maxRowCountPerProc += rowsPerColor;
          end;

          case rndColor of
            tcRed:    purePixel := CreatePixel(255, 0, 0);
            tcGreen:  purePixel := CreatePixel(0, 255, 0);
            tcBlue:   purePixel := CreatePixel(0, 0, 255);
            tcYellow: purePixel := CreatePixel(230, 255, 0)
          end;

         //column loop
          while (yOffset <= maxRowCountPerProc) do
          begin
            //check if the yOffset is still in bounds with the total buffer height,
            //since maxRowCountPerProc can be greater due to the fact that it wont stop at the maxsize of the buffer,
            //which is a pre calculated one, he stops only at the const max height I have set, so he ignores the buffers bounds!
            if (yOffset < pixelBuffer^.Height) then
            begin
              currCell := nextRow;

              //row loop
              while xOffset <= (pixelBuffer^.Width - 1) do
              begin
                currCell^ := purePixel;
                currCell += 1;
                xOffset += 1;
              end;
                yOffset += 1;
                xOffset := 0;
                nextRow += pixelBuffer^.Width;
            end

            else
              goto FIRSTTIME;
          end;
       end;

    begin
      Write_N_RowsOfColor(color, rowsPerColor);  //shall color the first 3 rows in pure red
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
