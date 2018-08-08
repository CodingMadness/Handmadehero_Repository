unit Helper;
{$mode objfpc}{$H+}

interface
    uses
      Classes, windows, SysUtils, crt;

    const
      RETURN_MESSAGE_LENGTH = 38;

    type
      TRoutineName = String[6];

      TCallReturnMessage = String[RETURN_MESSAGE_LENGTH];

      TLockState = record
        ID: QWORD;
        Locked: BOOL;
        Message: TCallReturnMessage;
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

     function GetFunctionReturnMessage(const returnCode: HRESULT): TCallReturnMessage;
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

    function GetFunctionReturnMessage(const returnCode: HRESULT): TCallReturnMessage;
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
      tmpCode     := DWORD(returnCode);
      msgBuf      := LPSTR(@msgBuf);

      FormatMessageA(bufferFlags, nil, tmpCode, currLang, msgBuf, 0, nil);  //range check error
      result := TCallReturnMessage(msgBuf);
      hMem := PQWord(@msgBuf)^;
      LocalFree(hMem);
      msgBuf := nil;
    end;

    procedure PrintLockState(const currState: PLockState; routineName: TRoutineName);
    begin
      routineName := upcase('<' + routineName + '>');
    //------------------------------------------//
      write('Count of successful ', routineName);
      TextColor(LightRed);
      writeln('(', currState^.ID, ')');
      TextColor(white);
    //------------------------------------------//
      write('Did the ', routineName, ' succeed:? ');
      TextColor(LightRed);
      writeln('(', currState^.Locked, ')');
      TextColor(white);
    //------------------------------------------//
      write('Result Message of ', routineName, ' based on the success of the', routineName ,' after it is finished: ');
      TextColor(LightRed);
      writeln('(', currState^.Message, ')');
      TextColor(white);
    //------------------------------------------//
      writeln;
    end;

end.

