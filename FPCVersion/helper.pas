unit Helper;
{$mode objfpc}{$H+}

interface
    uses
      Classes, windows, SysUtils, crt;

    //const
      //OPERATIONS : array[0..1] of String[6] = ('LOCK', 'UNLOCK');

    type
      TOperationName = String[6]; //6 chars for lock and unlock

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

     function GetFunctionReturnMessage(const code: HRESULT): TCallReturnMessage;
     procedure PrintOperationsState(const currState: PAfterOperationData);
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
    procedure WriteNumberToTextBuffer(const info: PAfterOperationData; const call: TOperationName);
    begin
      write('This is number: ');
      TextColor(Green);
      write('(', info^.CallCount, ')');
      TextColor(White);
      write('of: ' + call, ' calls');
      TextColor(white);
      writeln;
    end;

    procedure WriteSuccessToTextBuffer(const info: PAfterOperationData; const call: TOperationName);
    begin
      write('Did the current : ' + call, ' succeed?: ');
      TextColor(Green);
      write('(', info^.currentOperation.IsOperationAlsoSuccessFul, ')');
      TextColor(White);
      writeln;
    end;

    procedure WriteCallMessageTextBuffer(const info: PAfterOperationData; const call: TOperationName);
    begin
      write('Result Message of: ');

      if info^.currentOperation.IsOperationAlsoSuccessFul then
        TextColor(Green)
      else
        TextColor(Red);

      write('(', info^.ReturnMessage, ')');
      writeln;
      TextColor(White);
    end;

    procedure WriteSucceededUntilNowToTextBuffer(const info: PAfterOperationData; const call: TOperationName);
    begin
     write('Count of succeeded  ', call, 's until now: ');
     TextColor(Red);
     write(info^.SuceededUntilNow);
     writeln;
     TextColor(White);
    end;

    procedure WriteFailedUntilNowToTextBuffer(const info: PAfterOperationData; const call: TOperationName);
    begin
     write('Count of failed  ', call, 's until now: ');
     TextColor(Red);
     write(info^.FailedUntilNow);
     writeln;
     TextColor(White);
    end;
   {$EndRegion}

    procedure PrintOperationsState(const currState: PAfterOperationData);
    var
     currentOperation: string[6];
    begin
      case currState^.currentOperation.IsOperationLocking of     //---> error: SIGSEGV
        YES:          currentOperation := 'LOCK';
        NO:           currentOperation := 'UNLOCK';
        UNDEFINED:    currentOperation := 'NOCALL';
      end;

      WriteNumberToTextBuffer(@currState, currentOperation);
      WriteSuccessToTextBuffer(@currState, currentOperation);
      WriteCallMessageTextBuffer(@currState, currentOperation);
      WriteSucceededUntilNowToTextBuffer(@currState, currentOperation);
      WriteFailedUntilNowToTextBuffer(@currState, currentOperation);
      WriteEmptyLines(2);
    end;
end.

