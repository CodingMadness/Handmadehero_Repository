unit Helper;
{$mode objfpc}
{$H+}

interface
    uses
      Classes, windows, SysUtils , crt;

    type
      TOperationName = String[6]; //6 chars to occupy enough for lock and unlock string

      TCallReturnMessage = String[38];

      T3BITS = (UNDEFINED, YES, NO);

      TCurrentOperation = record
        case IsOperationLocking: T3BITS of
          YES, false: (IsOperationAlsoSuccessFul: boolean;);
          UNDEFINED:();
      end;

      TLargeCount = QWORD;

      TAfterOperationStatus = record
        currentOperation: TCurrentOperation;
        CallCount: TLargeCount;
        SuceededUntilNow, FailedUntilNow: TLargeCount;
        ReturnMessage: TCallReturnMessage;
      end;

      PAfterOperationData = ^TAfterOperationStatus;

      TPerformanceMeasure = record
       lastCycleCount, endCycleCount, cyclesElapsed, megaCyclesElapsed,
       lastCounter, endCounter, timeElapsed,
       millisecondsPerFrame, framesPerSecond, ClocksPerSecond: TLargeInteger;
      end;

      TPixelCount = integer;

      {Little Endian bit-order from Right -> Left (start: 2^0 -> end: 2^7)}
      {$PACKENUM 1}
      TColor = (
                  //Q: How many bits I need to <shr> in order to get the firstColor of TInternalColor
                  tcRed = 1,    //0000 0001  => 1 shr 4 = 16
                  tcGreen=2,    //0000 0010  => 2 shr 4 = 32
                  tcBlue,       //0000 0011  => 3 shr 4 = 48  + TColor[0]
                  tcYellow,     //0000 0100  => 4 shr 4 = 64
                  tcCyan,       //0000 0101  => 5 shr 4 = 80  + TColor[4]
                  tcPurple,     //0000 0110  => 6 shr 4 = 96
                  tcGrey,       //0000 0111
                  tcBrown       //0000 1000
                );

     TColorSet = set of TColor;

     function GetFunctionReturnMessage(const code: HRESULT): TCallReturnMessage;
     procedure PrintOperationsState(const currState: PAfterOperationData);
     function GetRndColor: TColor;

     procedure StartSpeedMeasureOnProgramStartup;
     procedure StartSpeedMeasureBeforeGameLogicBegins;
     procedure StartSpeedMeasureAfterLoopGameLogicEnd;
     procedure OutputAllSpeedMeasurements;

implementation
    var
      ONE_PERFORMANCEMEASURETOOL: TPerformanceMeasure;


    function xor128_RNG: QWord;
    const
      seed_x:QWord=123456789;
      seed_y:QWord=362436069;
      seed_z:QWord=521288629;
      seed_w:QWord=88675123;
    var
      t: QWord;
    begin
       t := (seed_x xor (seed_x shl 11));
       seed_x := seed_y;
       seed_Y := seed_z;
       seed_z := seed_w;
       seed_w := (seed_w xor (seed_w shr 19)) xor (t xor (t shr 8));
       result := seed_w;
    end;


    function GetRndColor: TColor;
    type
     {$PackEnum 2}
     TInternalColor = (
                  tIRed = 16,
                  tIGreen = 32,
                  tIBlue = 64,     //miss!
                  tIYellow = 128,
                  tICyan = 256,    //miss!
                  tIPurple = 512, //miss!
                  tIGrey = 1024, //miss!
                  tIBrown = 2048
                );
     TInternalColorInfo = record
       currColor, nextColor: TInternalColor;
       isCurrColorClosest: boolean;
       mappedPosForTColor, tcolorPos: byte;
     end;

    const
      bitshiftPos: byte = 0;
      func_callNr: byte = 0;
      MAXBYTELEN_OF_RNDVALUE = 16;
    var
      rng: QWord;
      onebyteFrom16byte: PByte;
      loopIndex, maxIndex: uint16;
      distanceToCurrcolor, distanceToNextcolor: Int16;
      mostRNDColor: TColorset;
      firstColor, lastColor: TInternalColor;
      currColorInfo: TInternalColorInfo;
    begin
       {$region RNG code}
       rng := xor128_RNG;

       if func_callNr >= MAXBYTELEN_OF_RNDVALUE then
       begin
         func_callNr := 0;
         bitshiftPos := bitshiftPos div 2;
         rng := xor128_RNG xor (rng shr bitshiftPos);
       end;

       onebyteFrom16byte := PByte(@rng) + func_callNr;

       {  if onebyteFrom16byte^ is even and this function got called 3 times, divide it by 2,
          to mamappedPoske a bit more randomness happen
       }
       if ((onebyteFrom16byte^ and 1) = 0) and
          (onebyteFrom16byte^ >= 150)      and
          (func_callNr = 2)                then
         onebyteFrom16byte^ := onebyteFrom16byte^ shr 1;
       {$EndRegion RNG code}

       {$Region ALGORITHM BASED PROPER INITIALIZATION}
       with currColorInfo do
       begin
         firstColor := low(TInternalColor);
         lastColor := high(TInternalColor);

         currColor := firstColor;
         nextColor := firstColor;

         isCurrColorClosest := false;
         mappedPosForTColor := 1;
         tcolorPos := 1;

         maxIndex  := ord(lastColor);
         loopIndex := ord(firstColor);

         distanceToCurrcolor := onebyteFrom16byte^ - uint16(firstColor);
         mostRNDColor := [];
       {$EndRegion}

       while loopIndex < maxIndex do
       begin
         nextColor := TInternalColor(ord(nextColor)*2);
         distanceToNextcolor := onebyteFrom16byte^ - uint16(nextColor);

         if distanceToNextcolor < 0 then
           distanceToNextcolor *= -1;

         if (distanceToCurrcolor < 0)  then
           distanceToCurrcolor *= -1;

         {clear <mostRNDColor> when another color with closer range to the 1byte of the 16byte value were found}
         if (distanceToCurrcolor < distanceToNextcolor) and (not isCurrColorClosest)  then
         begin
           mostRNDColor:= [];
           //mappedPosForTColor += 1;
           mostRNDColor += [TColor(tcolorPos)];
           isCurrColorClosest := distanceToCurrcolor < distanceToNextcolor;
         end

         {clear <mostRNDColor> when another color with closer range to the 1byte of the 16byte value were found}
         else if not isCurrColorClosest then
         begin
           mostRNDColor:= [];
           currColor := nextColor;
           mappedPosForTColor += 1;
           mostRNDColor += [TColor(mappedPosForTColor)];
           distanceToCurrcolor := distanceToNextcolor;
           isCurrColorClosest := false;
         end;

         loopIndex *= 2;
         tcolorPos += 1;
         end;
       end;

       bitshiftPos += 1;
       func_callNr += 1;
       result := TColor(currColorInfo.mappedPosForTColor);
      end;


    function _rdtsc: QWORD; assembler;
    asm
      rdtsc
    end;

    function GetFunctionReturnMessage(const code: HRESULT): TCallReturnMessage;
    var
      bufferFlags: DWORD;
      currLang: DWORD;
      msgBuf: LPSTR;
      hMem: HLOCAL;
      tmpCode: DWORD;
    begin
      msgBuf := nil;
      bufferFlags := DWORD(FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS);
      currLang    := DWORD(MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT));
      tmpCode     := DWORD(code);

      FormatMessageA(bufferFlags, nil, tmpCode, currLang, LPSTR(@msgBuf), 0, nil);
      result := TCallReturnMessage(msgBuf);
      hMem := PQWord(@msgBuf)^;
      LocalFree(hMem);
      msgBuf := nil;
    end;

    procedure Write_EmptyLines(const newLineCount: DWORD);
    var start: DWORD;
    begin
      for start := 0 to newLineCount do
        writeln;
    end;

    {$Region PRIVATE SECTION}
    procedure Write_CallCountToTextBuffer(const info: PAfterOperationData; const call: TOperationName);
    begin
      TextColor(127);
      write('Current number of ', '[',call,']', ' calls:          ');      {
                                                                             10chars extra space to be correctly aligned with the rest
                                                                             of the stats which are printed out!
                                                                           }
      TextColor(Green);
      write('(', info^.CallCount, ')');
      TextColor(White);
      writeln;
    end;

    procedure Write_WasSuccessToTextBuffer(const info: PAfterOperationData; const call: TOperationName);
    begin
      write('Did the current : ' , '[',call,']', ' succeed?:       '); {
                                                                        7chars extra space to be correctly aligned with the rest
                                                                        of the stats which are printed out!
                                                                        }
      TextColor(Green);
      write('(', info^.currentOperation.IsOperationAlsoSuccessFul, ')');
      TextColor(White);
      writeln;
    end;

    procedure Write_CallMessageToTextBuffer(const info: PAfterOperationData; const call: TOperationName);
    begin
      write('Result Message of : call:', call, '                       '); //20char extra space!

      if info^.currentOperation.IsOperationAlsoSuccessFul then
        TextColor(Green)
      else
        TextColor(Red);

      write('(', info^.ReturnMessage, ')');
      writeln;
      TextColor(White);
    end;

    procedure Write_SucceededUntilNowToTextBuffer(const info: PAfterOperationData; const call: TOperationName);
    begin
     write('Count of succeeded ', '[', call, 'S', ']', ' until now:    ');{
                                                                             4chars extra space to be correctly aligned with the rest
                                                                             of the stats which are printed out!
                                                                           }
     TextColor(Green);
     write('(', info^.SuceededUntilNow, ')');
     writeln;
     TextColor(White);
    end;

    procedure Write_FailedUntilNowToTextBuffer(const info: PAfterOperationData; const call: TOperationName);
    begin
     write('Count of failed ', '[', call, 'S', ']', ' until now:       '); {
                                                                             7chars extra space to be correctly aligned with the rest
                                                                             of the stats which are printed out!
                                                                           }
     TextColor(Red);
     write('(', info^.FailedUntilNow, ')');
     writeln;
     TextColor(White);
    end;
   {$EndRegion}

    procedure PrintOperationsState(const currState: PAfterOperationData);
    var
     currentOperation: string[15];
    begin
      case currState^.currentOperation.IsOperationLocking of
        YES:          currentOperation := 'LOCK';
        NO:           currentOperation := 'UNLOCK';
        UNDEFINED:    currentOperation := 'NOCALLWEREMADE';
      end;

      Write_CallCountToTextBuffer(currState, currentOperation);
      Write_WasSuccessToTextBuffer(currState, currentOperation);
      Write_CallMessageToTextBuffer(currState, currentOperation);
      Write_SucceededUntilNowToTextBuffer(currState, currentOperation);
      Write_FailedUntilNowToTextBuffer(currState, currentOperation);
      Write_EmptyLines(2);
    end;

    procedure StartSpeedMeasureOnProgramStartup;
    begin
      QueryPerformanceCounter(ONE_PERFORMANCEMEASURETOOL.ClocksPerSecond);
    end;

    procedure StartSpeedMeasureBeforeGameLogicBegins;
    begin
      QueryPerformanceCounter(@ONE_PERFORMANCEMEASURETOOL.lastCounter);
    end;

    procedure StartSpeedMeasureAfterLoopGameLogicEnd;
    begin
      with ONE_PERFORMANCEMEASURETOOL do
      begin
        endCycleCount := _rdtsc;
        QueryPerformanceCounter(endCounter);

        cyclesElapsed := TLargeInteger(endCycleCount - lastCycleCount);
        timeElapsed := endCounter - lastCounter;

        millisecondsPerFrame := (1000*timeElapsed) div ClocksPerSecond;
        framesPerSecond := ClocksPerSecond div timeElapsed;
        megaCyclesElapsed := cyclesElapsed div (1000 * 1000);

        lastCounter := endCounter;
        lastCycleCount := endCycleCount;
      end;
    end;

    procedure OutputAllSpeedMeasurements;
    begin
      with ONE_PERFORMANCEMEASURETOOL do
      begin
        {Output of the computed MillisecondsPerFrame}
        write(StdErr, 'MillisecondsPerFrame:  ');
        TextColor(Green);
        write('(', millisecondsPerFrame, ')', sLineBreak, sLineBreak); //2new lines

        {Output of the computed FramesPerSecond}
        write(StdErr, 'FramesPerSecond:  ');
        TextColor(Green);
        write('(', framesPerSecond, ')', sLineBreak);  // //2new lines

        {Output of the computed MegaCyclesElapsed}
        write(StdErr, 'MegaCyclesElapsed in MHZ:  ');
        TextColor(Green);
        write('(', megaCyclesElapsed, ')', sLineBreak );  // //2new lines
      end;
    end;
end.

