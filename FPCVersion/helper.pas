unit Helper;
{$mode objfpc}{$H+}

interface
    uses
      Classes, windows, SysUtils, crt;

    type
      TRoutineName = String[6];

      TCallReturnMessage = String[38];

      TLockState = record
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
     procedure PrintLockState(const currState: PLockState; routineName: TRoutineName);

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

    procedure PrintLockState(const currState: PLockState; routineName: TRoutineName);
    begin
      routineName := upcase('<' + routineName + '>');
    //------------------------------------------//
      write('Count of successful ', routineName, ' calls');
      TextColor(LightRed);
      writeln('(', currState^.SuccessCount, ')');
      TextColor(White);
    //------------------------------------------//
      write('Count of failed ', routineName, ' calls');
      TextColor(LightRed);
      writeln('(', currState^.FailureCount, ')');
      TextColor(white);
    //------------------------------------------//
      write('Did the ', routineName, ' succeed:? ');
      TextColor(LightRed);
      writeln('(', currState^.Locked, ')');
      TextColor(white);
    //------------------------------------------//
      write('Result Message of ', routineName, ' based on the success of the ', routineName ,' after it is finished: ');
      TextColor(LightRed);
      writeln('(', currState^.Message, ')');
    //------------------------------------------//
      TextColor(Green);
      writeln('_________________________________________________________________________________________________________________________');
      TextColor(White);
    end;

end.

