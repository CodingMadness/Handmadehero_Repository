unit Helper;
{$mode objfpc}{$H+}

interface
    uses
      Classes, windows, SysUtils , crt;

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

    procedure WriteEmptyLines(const newLineCount: DWORD);
    var start: DWORD;
    begin
      for start := 0 to newLineCount do
        writeln;
    end;

    {$Region PRIVATE SECTION}
    procedure WriteCallCountToTextBuffer(const info: PAfterOperationData; const call: TOperationName);
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

    procedure WriteSuccessToTextBuffer(const info: PAfterOperationData; const call: TOperationName);
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

    procedure WriteCallMessageToTextBuffer(const info: PAfterOperationData; const call: TOperationName);
    begin
      write('Result Message of:                       '); //20char extra space!

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
     write('Count of succeeded ', '[', call, 'S', ']', ' until now:    ');{
                                                                             4chars extra space to be correctly aligned with the rest
                                                                             of the stats which are printed out!
                                                                           }
     TextColor(Green);
     write('(', info^.SuceededUntilNow, ')');
     writeln;
     TextColor(White);
    end;

    procedure WriteFailedUntilNowToTextBuffer(const info: PAfterOperationData; const call: TOperationName);
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
     currentOperation: string[6];
    begin
      case currState^.currentOperation.IsOperationLocking of
        YES:          currentOperation := 'LOCK';
        NO:           currentOperation := 'UNLOCK';
        UNDEFINED:    currentOperation := 'NOCALL';
      end;

      WriteCallCountToTextBuffer(currState, currentOperation);
      WriteSuccessToTextBuffer(currState, currentOperation);
      WriteCallMessageToTextBuffer(currState, currentOperation);
      WriteSucceededUntilNowToTextBuffer(currState, currentOperation);
      WriteFailedUntilNowToTextBuffer(currState, currentOperation);
      WriteEmptyLines(2);
    end;
end.

