unit Helper;
{$mode objfpc}{$H+}

interface
    uses
      Classes, windows, SysUtils, crt;

    type
      TFunctioName = String[10];

      TCallReturnMessage = String[38];

      TLockState = record
        FunctionName: TFunctioName;
        Locked: boolean;
        Message: TCallReturnMessage;
        SuccessCount, FailureCount: QWORD;
      end;

      PLockState = ^TLockState;

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
     procedure PrintLockState(const currState: PLockState);

implementation
    {
      {ELock/EUnlock}
      constructor ELock.Init(const currState: PLockState);
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

    procedure PrintLockState(const currState: PLockState);
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
      TextColor(LightRed);
      write('(', currState^.FailureCount, ') ');
      TextColor(white);
      write('of failed: ', currState^.functionName, ' calls');
      TextColor(white);
      writeln;
    //------------------------------------------//
      write('Did the ', currState^.functionName, ' succeed:? ');

      if currState^.Locked then
        TextColor(LightGreen)
      else
        TextColor(LightGreen);

      writeln('(', currState^.Locked, ')');
      TextColor(white);
    //------------------------------------------//
      write('Result Message of ', currState^.functionName, ' based on the success of the ', currState^.functionName ,' after it is finished: ');

      if currState^.Locked then
        TextColor(LightGreen)
      else
        TextColor(LightGreen);

      writeln('(', currState^.Message, ')');
    //------------------------------------------//
      TextColor(Green);
      writeln('_________________________________________________________________________________________________________________________');
      TextColor(White);
    end;

end.

