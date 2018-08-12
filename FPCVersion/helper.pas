unit Helper;
{$mode objfpc}{$H+}

interface
    uses
      Classes, windows, SysUtils, crt;

    type
      TFunctioName = String[8];

      TCallReturnMessage = String[38];

      TFilter = (SucceededOnes, FailedOnes, All);

      TCall = (Lock, Unlock);

      TNumber = QWORD;

      TAfterCallData = record
        Number: TNumber;
        CallSuceeded: Boolean;
        FunctionName: TFunctioName;
        ReturnMessage: TCallReturnMessage;
      end;

      TLockState = record
        infoAfterLock : TAfterCallData;
        SuceededUntilNow, FailedUntilNow: TNumber;
      end;

      TUnlockState = record
        infoAfterUnlock : TAfterCallData;
        SuceededUntilNow, FailedUntilNow: TNumber;
      end;

      TManipulatedRegionState = record //make a variant-record out of this!
        LockState: TLockState;
        UnlockState: TUnlockState;
      end;

      PLockState = ^TLockState;
      PUnlockState = ^TUnlockState;

      PManinpulatedRegionState = ^TManipulatedRegionState;


     function GetFunctionReturnMessage(const code: HRESULT): TCallReturnMessage;
     procedure PrintLockState(const info: PLockState);
     procedure PrintUnlockState(const info: PUnlockState);
     function _rdtsc: QWORD; assembler;


     var ClocksPerSecond: TLargeInteger;

implementation

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

    procedure WriteEmptyLines(const newLines: DWORD);
    var start: DWORD;
    begin
      for start := 0 to newLines do
        writeln;
    end;

    {$Region PRIVATE SECTION}
    procedure WriteNumberToTextBuffer(const info: PManinpulatedRegionState; const call: TCall);
    var
      callName: TCallReturnMessage;
      number: TNumber;
    begin
      if call = Lock then
      begin
        callName := info^.LockState.infoAfterLock.FunctionName;
        number := info^.LockState.infoAfterLock.Number;
      end

      else
      begin
        callName := info^.UnlockState.infoAfterUnlock.FunctionName;
        number := info^.UnlockState.infoAfterUnlock.Number;
      end;

      write('This is number: ');
      write('(', number, ') ');
      TextColor(white);
      write('of ', callName, ' calls');
      TextColor(white);
      writeln;
    end;

    procedure WriteSuccessToTextBuffer(const info: PManinpulatedRegionState; const call: TCall);
    var
      callName: TCallReturnMessage;
      succeed: boolean;
    begin
      if call = Lock then
      begin
        callName := info^.LockState.infoAfterLock.FunctionName;
        succeed := info^.LockState.infoAfterLock.CallSuceeded;
      end

      else
      begin
        callName := info^.UnlockState.infoAfterUnlock.FunctionName;
        succeed := info^.UnlockState.infoAfterUnlock.CallSuceeded;
      end;

      write('Did the ' + callName + ' succeed:? ');

      if succeed then
        TextColor(Green)
      else
        TextColor(Red);

      writeln('(', succeed, ')');
      TextColor(white);
    end;

    procedure WriteCallMessageTextBuffer(const info: PManinpulatedRegionState; const call: TCall);
     var
      callMsg: TCallReturnMessage;
      succeed: boolean;
    begin
      if call = Lock then
      begin
        callMsg := info^.LockState.infoAfterLock.ReturnMessage;
        succeed := info^.LockState.infoAfterLock.CallSuceeded;
      end

      else
      begin
        callMsg := info^.UnlockState.infoAfterUnlock.ReturnMessage;
        succeed := info^.UnlockState.infoAfterUnlock.CallSuceeded;
      end;

     write('Result Message of: ');

      if succeed then
        TextColor(Green)
      else
        TextColor(Red);

      write('(', callMsg, ')');
      writeln;
      TextColor(White);
    end;

    procedure WriteSucceededUntilNowToTextBuffer(const info: PManinpulatedRegionState; const call: TCall);
    var
      callName: TCallReturnMessage;
      succeedUntilNow: TNumber;
    begin
      if call = Lock then
      begin
        callName := info^.LockState.infoAfterLock.FunctionName;
        succeedUntilNow := info^.LockState.SuceededUntilNow;
      end

      else
      begin
        callName := info^.UnlockState.infoAfterUnlock.ReturnMessage;
        succeedUntilNow := info^.UnlockState.SuceededUntilNow;
      end;

     write('Count of succeeded  ', callName, ' until now: ');
     TextColor(Green);
     write(succeedUntilNow);
     writeln;
     TextColor(White);
    end;

    procedure WriteFailedUntilNowToTextBuffer(const info: PManinpulatedRegionState; const call: TCall);
    var
      callName: TCallReturnMessage;
      failedCountUntilNow: TNumber;
    begin
      if call = Lock then
      begin
        callName := info^.LockState.infoAfterLock.FunctionName;
        failedCountUntilNow := info^.LockState.FailedUntilNow;
      end

      else
      begin
        callName := info^.UnlockState.infoAfterUnlock.ReturnMessage;
        failedCountUntilNow := info^.UnlockState.FailedUntilNow;
      end;

     write('Count of failed  ', callName, ' until now: ');
     TextColor(Red);
     write(failedCountUntilNow);
     writeln;
     TextColor(White);
    end;

    procedure WriteTotalCallCountToTextBuffer(const info: PManinpulatedRegionState; const call: TCall);
     var
      callName: TCallReturnMessage;
      totalCallCount: TNumber;
    begin
      if call = Lock then
      begin
        callName := info^.LockState.infoAfterLock.FunctionName;
        totalCallCount := info^.LockState.FailedUntilNow +
                          info^.LockState.SuceededUntilNow +
                          info^.LockState.infoAfterLock.Number;
      end

      else
      begin
        callName := info^.UnlockState.infoAfterUnlock.ReturnMessage;
        totalCallCount := info^.UnlockState.FailedUntilNow +
                          info^.UnlockState.SuceededUntilNow +
                          info^.LockState.infoAfterLock.Number;
      end;

     write('Total count of called  ', callName, ' until now: ');
     TextColor(Yellow);
     write('(', totalCallCount, ')');
     writeln;
     TextColor(White);
    end;

    {$EndRegion}

    procedure PrintLockState(const info: PLockState);
    var
     pMRS: TManipulatedRegionState;
    begin
      pMRS.LockState := info^;

      WriteNumberToTextBuffer(@pMRS, Lock);
      WriteSuccessToTextBuffer(@pMRS, Lock);
      WriteCallMessageTextBuffer(@pMRS, Lock);
      WriteSucceededUntilNowToTextBuffer(@pMRS, Lock);
      WriteFailedUntilNowToTextBuffer(@pMRS, Lock);
      WriteTotalCallCountToTextBuffer(@pMRS, Lock);

      WriteEmptyLines(2);
    end;

    procedure PrintUnlockState(const info: PUnlockState);
    var
     pMRS: TManipulatedRegionState;
    begin
      pMRS.UnlockState := info^;

      WriteNumberToTextBuffer(@pMRS, Unlock);
      WriteSuccessToTextBuffer(@pMRS, Unlock);
      WriteCallMessageTextBuffer(@pMRS, Unlock);
      WriteSucceededUntilNowToTextBuffer(@pMRS, Unlock);
      WriteFailedUntilNowToTextBuffer(@pMRS, Unlock);

      WriteEmptyLines(2);
    end;

end.

