unit Helper;
{$mode objfpc}{$H+}

interface
    uses
      Classes, windows, SysUtils, crt;

    type
      TFunctioName = String[8];

      TCallReturnMessage = String[38];

      TLockState = (INITIAL=-1, LOCKED=0, UNLOCKED=1);        //added..

      TLockInfo = record
        FunctionName: TFunctioName;
        State: TLockState;               //changed to..
        Message: TCallReturnMessage;
        SuccessCount, FailureCount: QWORD;
      end;

      PLockInfo = ^TLockInfo;

      {
      ELock = class(Exception)
      private
        fLockState: PLockState;

        function GetLocked: bool;
        function GetReturnMessage: TCallReturnMessage;
        function GetID: QWORD;

      public
        property Locked:        BOOL                   read GetLocked;
        property ReturnMessage: TCallReturnMessage     read GetReturnMessage;
        property CurrentID:     QWORD                  read GetID;
        constructor Init(const currState: PLockState);
      end;

      EUnlock = class(ELock);
      }

     function GetFunctionReturnMessage(const code: HRESULT): TCallReturnMessage;
     procedure PrintLockState(const currState: PLockInfo);

implementation
    {
      {ELock/EUnlock}
      constructor ELock.Init(const currState: PLockInfo);
      begin
        fLockState := currState;
      end;

      function ELock.GetLocked: BOOL;
      begin
        result := fLockState^.Locked;
      end;

      function ELock.GetReturnMessage: TCallReturnMessage;
      begin
        result := fLockState^.Message;
      end;

      function ELock.GetID: QWORD;
      begin
        result := fLockState^.ID;
      end;
      {ELock/EUnlock}
    }

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

    procedure PrintLockState(const currState: PLockInfo);
    var
      suceedCall: boolean;
    begin
    //------------------------------------------//
      write('This is number: ');
      TextColor(LightGreen);
      write('(', currState^.SuccessCount, ') ');
      TextColor(white);
      write('of successful: ', currState^.functionName, ' calls');
      TextColor(white);
      writeln;
    //------------------------------------------//
      write('This is number: ');
      TextColor(Red);
      write('(', currState^.FailureCount, ') ');
      TextColor(white);
      write('of failed: ', currState^.functionName, ' calls');
      TextColor(white);
      writeln;
    //------------------------------------------//
      write('Did the ', currState^.functionName, ' succeed:? ');
      suceedCall := currState^.State <> INITIAL;
      if suceedCall then
        TextColor(Green)
      else if currState^.State = INITIAL then
        TextColor(Red);

      writeln('(', suceedCall, ')');
      TextColor(white);
    //------------------------------------------//
      write('Result Message of  ', currState^.functionName, ': ');

      if currState^.State <> INITIAL then
        TextColor(Green)
      else if currState^.State = INITIAL then
        TextColor(Red);

      writeln('(', currState^.Message, ')');
    //------------------------------------------//
      WriteEmptyLines(3);
      TextColor(White);
    end;

end.

